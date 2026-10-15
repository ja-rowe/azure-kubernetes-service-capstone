output "cluster_acr_pull_principal" {
  value = data.azuread_service_principal.cluster.display_name
}
