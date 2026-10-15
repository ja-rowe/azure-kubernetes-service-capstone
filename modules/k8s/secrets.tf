# Secrets come from the environment's Key Vault through the Secrets Store CSI driver. Pods that
# use the sock-shop-secrets ServiceAccount authenticate as the environment's identity (workload
# identity); that identity can read only its own environment's vault. Values never pass through
# Terraform state, the pipeline or the source.
#
# The ServiceAccount and the SecretProviderClass (which vault, which identity) are owned by the
# platform/ root, so a deployment cannot point its namespace at another environment's identity.

locals {
  service_account_name       = "sock-shop-secrets"
  secret_provider_class_name = "sock-shop-keyvault"
  catalogue_db_secret_name   = "catalogue-db"
}
