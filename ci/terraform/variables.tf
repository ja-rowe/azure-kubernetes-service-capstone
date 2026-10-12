variable "project_name" {
  default = "T2_T3"
}

variable "github_service_connection_name" {
  description = "Existing GitHub service connection in the project"
  default     = "ja-rowe"
}

variable "capstone_github_repo" {
  description = "GitHub repository holding the ci/ pipeline YAML"
  default     = "ja-rowe/azure-kubernetes-service-capstone"
}

variable "capstone_branch" {
  default = "main"
}

variable "acr_name" {
  default = "sockshop1"
}

variable "acr_resource_group" {
  default = "aks-terraform"
}

variable "acr_service_connection_name" {
  default = "acr-sockshop1"
}

variable "identity_resource_group" {
  default = "t3-ci-rg"
}

variable "location" {
  default = "centralus"
}
