variable "cluster_name" {
  default = "aks-terraform"
}

variable "cluster_resource_group" {
  default = "aks-terraform"
}

variable "acr_name" {
  default = "sockshop1"
}

variable "acr_resource_group" {
  default = "aks-terraform"
}

variable "state_storage_account" {
  default = "t3capstonetfstate"
}

variable "state_resource_group" {
  default = "t3-capstone-tfstate-rg"
}
