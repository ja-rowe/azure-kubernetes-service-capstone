terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  required_version = ">= 1.1.0"

  backend "azurerm" {}
}

provider "azurerm" {
  features {
  }
}

module "cluster" {
  source = "./modules/cluster"
}
