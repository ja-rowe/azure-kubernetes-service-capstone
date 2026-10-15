output "namespace" {
  value = data.kubernetes_namespace.sock_shop.metadata.0.name
}

# Empty until the cloud load balancer has assigned an address.
output "front_end_ip" {
  value = try(kubernetes_service.front_end.status.0.load_balancer.0.ingress.0.ip, "")
}
