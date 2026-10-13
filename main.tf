terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 5.8.0"
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
    client_id = var.CLIENT_ID
    client_secret = var.CLIENT_SECRET
}
