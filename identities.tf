# One managed identity per environment. Pipelines deploying an environment authenticate as that
# environment's identity (workload identity federation, no secret), so dev, staging and prod
# credentials are separate. Federated credentials are added with the Azure DevOps service
# connections (their subject contains the connection id); role assignments live in access/.

locals {
  environments = ["dev", "staging", "prod"]
}

resource "azurerm_user_assigned_identity" "environment" {
  for_each            = toset(local.environments)
  name                = "id-sockshop-${each.key}"
  resource_group_name = module.cluster.resource_group_name
  location            = var.location

  tags = {
    environment = each.key
    purpose     = "sock-shop deployments to ${each.key}"
  }
}
