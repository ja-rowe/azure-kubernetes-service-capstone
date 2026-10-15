# Delivery: the dev / staging / prod environments, their approvals and checks, and the two
# delivery pipelines (release-dev: automatic; promote: manual).
#
# Approvals and checks belong to the environment (the resource), not to the pipeline YAML, so
# changing a pipeline file cannot remove them. Azure DevOps evaluates them before the stage that
# uses the environment starts, in this order: Branch control -> Approval -> Exclusive lock.

locals {
  environments = ["dev", "staging", "prod"]
  gated        = ["staging", "prod"]

  delivery_pipelines = {
    "release-dev" = "release-dev.yml"
    "promote"     = "promote.yml"
  }
}

# The identity allowed to approve promotions (the owner of the PAT used to run this module).
data "azuredevops_users" "approver" {
  principal_name = var.approver_principal_name
}

resource "azuredevops_environment" "env" {
  for_each    = toset(local.environments)
  project_id  = data.azuredevops_project.project.id
  name        = each.key
  description = "Sock Shop ${each.key} (namespace sock-shop-${each.key}); managed by Terraform"
}

# Manual approval before anything is deployed to staging or prod.
resource "azuredevops_check_approval" "gate" {
  for_each             = toset(local.gated)
  project_id           = data.azuredevops_project.project.id
  target_resource_id   = azuredevops_environment.env[each.key].id
  target_resource_type = "environment"

  approvers             = [one(data.azuredevops_users.approver.users).id]
  requester_can_approve = true  # the approver is also the person who queues the promotion
  timeout               = 10080 # 7 days; on timeout the Deploy stage is skipped
  instructions          = "Open the Resolve stage summary of this run and review the image digests that will be deployed to ${each.key}. Approve only if they are what you intend to release."
}

# Only runs from main may deploy to staging or prod. Evaluated before the approval, so a run from
# any other branch fails without ever asking for approval.
resource "azuredevops_check_branch_control" "main_only" {
  for_each             = toset(local.gated)
  project_id           = data.azuredevops_project.project.id
  display_name         = "Only main may deploy to ${each.key}"
  target_resource_id   = azuredevops_environment.env[each.key].id
  target_resource_type = "environment"
  allowed_branches     = "refs/heads/main"
  timeout              = 1440
}

# One deployment at a time per environment. The stages in the YAML set lockBehavior
# (dev: runLatest, staging/prod: sequential), which is what makes the lock effective.
resource "azuredevops_check_exclusive_lock" "lock" {
  for_each             = toset(local.environments)
  project_id           = data.azuredevops_project.project.id
  target_resource_id   = azuredevops_environment.env[each.key].id
  target_resource_type = "environment"
  timeout              = 43200
}

# Pipelines may use the environments (otherwise the first run waits for a manual "Permit").
resource "azuredevops_pipeline_authorization" "environment" {
  for_each    = toset(local.environments)
  project_id  = data.azuredevops_project.project.id
  resource_id = azuredevops_environment.env[each.key].id
  type        = "environment"
}

resource "azuredevops_build_definition" "delivery" {
  for_each   = local.delivery_pipelines
  project_id = data.azuredevops_project.project.id
  name       = each.key
  path       = "\\service-release"

  # release-dev is started by the build pipelines' completion; promote is manual.
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

  # Pipeline-resource triggers resolve their source pipelines by name when the definition is
  # created, so create the build pipelines first.
  depends_on = [
    azuredevops_build_definition.pipeline,
    azuredevops_pipeline_authorization.github,
  ]
}

# ----------------------------------------------------------- security scanning

# Standalone security scan (ci/security-scan.yml); manual until it is wired into the release path.
resource "azuredevops_build_definition" "security_scan" {
  project_id = data.azuredevops_project.project.id
  name       = "security-scan"
  path       = "\\service-release"

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type             = "GitHub"
    repo_id               = var.capstone_github_repo
    branch_name           = var.capstone_branch
    yml_path              = "ci/security-scan.yml"
    service_connection_id = data.azuredevops_serviceendpoint_github.github.id
  }

  depends_on = [azuredevops_pipeline_authorization.github]
}

# The scan reads every service repository (dependency scan).
resource "azuredevops_pipeline_authorization" "security_scan_repository" {
  for_each    = toset(local.services)
  project_id  = data.azuredevops_project.project.id
  resource_id = data.azuredevops_git_repository.service[each.key].id
  type        = "repository"
  pipeline_id = azuredevops_build_definition.security_scan.id
}
