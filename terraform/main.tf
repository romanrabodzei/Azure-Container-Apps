/*
.Synopsis
    Main Bicep template for Azure Container Apps components.

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240619
*/

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.107.0"
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////// Locals and variables ///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

locals {
  deploymentDate                 = formatdate("yyyyMMddHHmm", timestamp())
  containerAppsResourceGroupName = var.containerAppsResourceGroupName == "" ? "az-${var.deploymentEnvironment}-container-apps-rg" : var.containerAppsResourceGroupName
  tagValue                       = var.tagValue == "" ? var.deploymentEnvironment : var.tagValue
  tags                           = { "${var.tagKey}" : local.tagValue }
}

variable "deploymentLocation" {
  type        = string
  description = "The location where the resources will be deployed."
  default     = "West Europe"
}

variable "deploymentEnvironment" {
  type        = string
  description = "The environment where the resources will be deployed."
  default     = "poc"
}

variable "containerAppsResourceGroupName" {
  type        = string
  description = "The name of the resource group where the Azure Update Manager resources will be deployed."
  default     = ""
}

variable "tagKey" {
  type    = string
  default = "environment"
}

variable "tagValue" {
  type    = string
  default = ""
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////// Resources //////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

resource "azurerm_resource_group" "this_resource" {
  name     = local.containerAppsResourceGroupName
  location = var.deploymentLocation
  tags     = local.tags
}
