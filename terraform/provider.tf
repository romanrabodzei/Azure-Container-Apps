terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.110"
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