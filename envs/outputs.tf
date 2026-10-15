output "environment" {
  value = var.environment
}

output "namespace" {
  value = module.k8s.namespace
}

# Promotion reads this from the source environment's state and applies it to the target.
output "images" {
  value = var.images
}

output "front_end_ip" {
  value = module.k8s.front_end_ip
}

output "replicas" {
  value = local.config.replicas
}

