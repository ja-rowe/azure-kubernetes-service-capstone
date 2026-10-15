variable "kubeconfig" {
  description = "Path to the kubeconfig used to reach the cluster"
  type        = string
}

variable "CARTS_IMG" {
}

variable "CATALOGUE_IMG" {
}

variable "CATALOGUE_DB_IMG" {
}

variable "ORDERS_IMG" {
}

variable "PAYMENT_IMG" {
}

variable "QUEUE_MASTER_IMG" {
}

variable "SHIPPING_IMG" {
}

variable "USER_IMG" {
}

variable "USER_DB_IMG" {
}

variable "FRONTEND_IMG" {
}

variable "namespace" {
  description = "Kubernetes namespace the Sock Shop is deployed into"
  default     = "sock-shop"
}

variable "replicas" {
  description = "Replicas of each stateless service (databases and the message broker always run one)"
  type        = number
  default     = 1
}

