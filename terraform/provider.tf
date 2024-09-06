terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.1"
    }
  } /*
  backend "remote" {
    organization = ""
    workspaces {
      name = ""
    }
  }*/
}

provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {}
