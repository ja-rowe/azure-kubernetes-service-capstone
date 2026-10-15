# One Key Vault per environment holding that environment's secrets. Only the environment's own
# identity can read it (pods via workload identity), and only the infrastructure pipeline, which
# generates the secrets, can write it. Access policies rather than Azure RBAC so the pipeline
# (Contributor) can manage access without an operator-only role assignment.

data "azurerm_client_config" "current" {}

locals {
  # Vault names are global; a short stable suffix derived from the subscription keeps them unique.
  key_vault_suffix = substr(sha1(data.azurerm_client_config.current.subscription_id), 0, 4)
}

resource "azurerm_key_vault" "environment" {
  for_each                   = toset(local.environments)
  name                       = "kv-sockshop-${each.key}-${local.key_vault_suffix}"
  resource_group_name        = module.cluster.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = false

  tags = {
    environment = each.key
  }
}

# The infrastructure pipeline writes the secrets it generates.
resource "azurerm_key_vault_access_policy" "pipeline" {
  for_each     = azurerm_key_vault.environment
  key_vault_id = each.value.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

# The environment's identity reads its own vault only.
resource "azurerm_key_vault_access_policy" "environment_reader" {
  for_each     = azurerm_key_vault.environment
  key_vault_id = each.value.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.environment[each.key].principal_id

  secret_permissions = ["Get", "List"]
}

# MySQL root password for catalogue-db, different in every environment.
resource "random_password" "catalogue_db_root" {
  for_each = toset(local.environments)
  length   = 24
  special  = false
}

resource "azurerm_key_vault_secret" "catalogue_db_root_password" {
  for_each     = azurerm_key_vault.environment
  name         = "catalogue-db-root-password"
  value        = random_password.catalogue_db_root[each.key].result
  key_vault_id = each.value.id

  depends_on = [azurerm_key_vault_access_policy.pipeline]
}
