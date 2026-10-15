variable "cluster_name" {
  default = "aks-terraform"
}

variable "cluster_resource_group" {
  default = "aks-terraform"
}

variable "kubeconfig" {
  description = "Path to the operator's kubeconfig (Entra ID, converted with kubelogin)"
  type        = string
  default     = "~/.kube/aks-terraform"
}

variable "state_resource_group" {
  default = "t3-capstone-tfstate-rg"
}

variable "state_storage_account" {
  default = "t3capstonetfstate"
}

variable "state_container" {
  default = "tfstate"
}
