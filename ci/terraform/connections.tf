# One Azure Resource Manager service connection per environment, each signing in as that
# environment's managed identity (id-sockshop-<env>) with workload identity federation: no secret
# is stored anywhere. What a connection can reach is what its identity is granted: its own
# namespace on the cluster (platform/) and its own Key Vault (keyvaults.tf).

locals {
  connection_environments = ["dev", "staging", "prod"]

  # Which delivery pipelines may use each environment's connection.
  connection_pipelines = {
    dev     = ["release-dev"]
    staging = ["promote"]
    prod    = ["promote"]
  }
  connection_pipeline_pairs = merge([
    for env, pipelines in local.connection_pipelines : {
      for p in pipelines : "${env}/${p}" => { env = env, pipeline = p }
    }
  ]...)
}

data "azurerm_user_assigned_identity" "environment" {
  for_each            = toset(local.connection_environments)
  name                = "id-sockshop-${each.key}"
  resource_group_name = var.acr_resource_group
}

resource "azuredevops_serviceendpoint_azurerm" "environment" {
  for_each                               = toset(local.connection_environments)
  project_id                             = data.azuredevops_project.project.id
  service_endpoint_name                  = "sockshop-${each.key}"
  description                            = "Deployments to ${each.key} as id-sockshop-${each.key}; managed by Terraform"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  azurerm_spn_tenantid                   = data.azurerm_client_config.current.tenant_id
  azurerm_subscription_id                = data.azurerm_subscription.current.subscription_id
  azurerm_subscription_name              = data.azurerm_subscription.current.display_name

  credentials {
    serviceprincipalid = data.azurerm_user_assigned_identity.environment[each.key].client_id
  }
}

# Trust between the connection and its identity (the subject contains the connection id).
resource "azurerm_federated_identity_credential" "environment_connection" {
  for_each                  = azuredevops_serviceendpoint_azurerm.environment
  name                      = "azure-devops-sockshop-${each.key}"
  user_assigned_identity_id = data.azurerm_user_assigned_identity.environment[each.key].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = each.value.workload_identity_federation_issuer
  subject                   = each.value.workload_identity_federation_subject
}

# Staging and prod credentials can only be issued to runs from main. The human approval is on the
# environment: checks on every resource a stage uses are evaluated before the stage starts, so
# these credentials are only handed out after the environment's approval as well.
resource "azuredevops_check_branch_control" "connection_main_only" {
  for_each             = toset(["staging", "prod"])
  project_id           = data.azuredevops_project.project.id
  display_name         = "Only main may use the ${each.key} credentials"
  target_resource_id   = azuredevops_serviceendpoint_azurerm.environment[each.key].id
  target_resource_type = "endpoint"
  allowed_branches     = "refs/heads/main"
  timeout              = 1440
}

# Each connection is usable only by the pipeline(s) that deploy its environment.
resource "azuredevops_pipeline_authorization" "connection" {
  for_each    = local.connection_pipeline_pairs
  project_id  = data.azuredevops_project.project.id
  resource_id = azuredevops_serviceendpoint_azurerm.environment[each.value.env].id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.delivery[each.value.pipeline].id
}
