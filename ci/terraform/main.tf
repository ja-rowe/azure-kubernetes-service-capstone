# Azure DevOps configuration for the service release path (see ../README.md):
#   (the 8 Azure Repos Git repositories are created by ../create-repos.sh, which also pushes them)
#   - ACR service connection (workload identity federation, no stored secret)
#   - the `aks-terraform` variable group
#   - the 16 `<svc>-test` / `<svc>-build` pipelines (YAML in this repo's ci/ directory, on GitHub)
#
# Authentication
#   Azure DevOps : export AZDO_PERSONAL_ACCESS_TOKEN=<PAT> and AZDO_ORG_SERVICE_URL=https://dev.azure.com/northwaylabs
#   Azure        : `az login` and export ARM_SUBSCRIPTION_ID

terraform {
  required_version = ">= 1.1.0"

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.16.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuredevops" {}

locals {
  services = ["carts", "orders", "shipping", "queue-master", "user", "payment", "catalogue", "front-end"]

  pipelines = merge(
    { for s in local.services : "${s}-test" => "${s}-test.yml" },
    { for s in local.services : "${s}-build" => "${s}-build.yml" },
  )
}

data "azuredevops_project" "project" {
  name = var.project_name
}

data "azuredevops_serviceendpoint_github" "github" {
  project_id            = data.azuredevops_project.project.id
  service_endpoint_name = var.github_service_connection_name
}

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

# ------------------------------------------------- ACR service connection (WIF)

resource "azurerm_resource_group" "ci" {
  name     = var.identity_resource_group
  location = var.location
}

resource "azurerm_user_assigned_identity" "ado" {
  name                = "t3-ado-acr-push"
  resource_group_name = azurerm_resource_group.ci.name
  location            = azurerm_resource_group.ci.location
}

resource "azurerm_role_assignment" "acr_push" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.ado.principal_id
}

resource "azuredevops_serviceendpoint_azurecr" "acr" {
  project_id                             = data.azuredevops_project.project.id
  service_endpoint_name                  = var.acr_service_connection_name
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  resource_group                         = var.acr_resource_group
  azurecr_name                           = var.acr_name
  azurecr_spn_tenantid                   = data.azurerm_client_config.current.tenant_id
  azurecr_subscription_id                = data.azurerm_subscription.current.subscription_id
  azurecr_subscription_name              = data.azurerm_subscription.current.display_name

  credentials {
    serviceprincipalid = azurerm_user_assigned_identity.ado.client_id
  }
}

resource "azurerm_federated_identity_credential" "ado" {
  name                      = "azure-devops-${var.acr_service_connection_name}"
  user_assigned_identity_id = azurerm_user_assigned_identity.ado.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azuredevops_serviceendpoint_azurecr.acr.workload_identity_federation_issuer
  subject                   = azuredevops_serviceendpoint_azurecr.acr.workload_identity_federation_subject
}

# ------------------------------------------------------------ variable group

# The group already exists with `containerRegistry`; import it first:
#   terraform import azuredevops_variable_group.aks_terraform T2_T3/2
resource "azuredevops_variable_group" "aks_terraform" {
  project_id   = data.azuredevops_project.project.id
  name         = "aks-terraform"
  description  = "Shared variables for the AKS deploy and the service build pipelines"
  allow_access = true

  variable {
    name  = "containerRegistry"
    value = "${var.acr_name}.azurecr.io"
  }

  variable {
    name  = "dockerRegistryServiceConnection"
    value = azuredevops_serviceendpoint_azurecr.acr.service_endpoint_name
  }
}

# ----------------------------------------------------- pipeline authorization

resource "azuredevops_pipeline_authorization" "acr" {
  project_id  = data.azuredevops_project.project.id
  resource_id = azuredevops_serviceendpoint_azurecr.acr.id
  type        = "endpoint"
}

resource "azuredevops_pipeline_authorization" "github" {
  project_id  = data.azuredevops_project.project.id
  resource_id = data.azuredevops_serviceendpoint_github.github.id
  type        = "endpoint"
}

resource "azuredevops_pipeline_authorization" "variable_group" {
  project_id  = data.azuredevops_project.project.id
  resource_id = azuredevops_variable_group.aks_terraform.id
  type        = "variablegroup"
}

# ----------------------------------------------------------------- pipelines

resource "azuredevops_build_definition" "pipeline" {
  for_each   = local.pipelines
  project_id = data.azuredevops_project.project.id
  name       = each.key
  path       = "\\service-release"

  # Triggers are defined in the YAML (repository-resource and pipeline-resource triggers).
  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type             = "GitHub"
    repo_id               = var.capstone_github_repo
    branch_name           = var.capstone_branch
    yml_path              = "ci/${each.value}"
    service_connection_id = data.azuredevops_serviceendpoint_github.github.id
  }

  depends_on = [azuredevops_pipeline_authorization.github]
}
