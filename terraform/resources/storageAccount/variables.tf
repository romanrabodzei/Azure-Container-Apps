/*
.Synopsis
    Terraform template for Standard Storage Account.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240817
*/

/// variables
variable "deploymentResourceGroupName" {
  type        = string
  description = "Deployment resource group name."
}

variable "deploymentLocation" {
  type        = string
  description = "The location where the resources will be deployed."
}

variable "storageAccountName" {
  type        = string
  description = "The name of the storage account."
}

variable "storageAccountKind" {
  type        = string
  description = "The kind of the storage account."
  default     = "StorageV2"
}

variable "storageAccountType" {
  type        = string
  description = "The type of the storage account."
  default     = "RAGZRS"
}

variable "storageAccountFileShareName" {
  type        = list(string)
  description = "The name of the file share."
}

variable "virtualNetworkResourceGroupName" {
  type        = string
  description = "The name of the resource group where the virtual network is located."
  default     = ""
}

variable "virtualNetworkName" {
  type        = string
  description = "The name of the virtual network."
  default     = ""
}

variable "virtualNetworkSubnetNames" {
  type        = list(string)
  description = "The name of the subnets."
  default     = []
}

variable "userAssignedIdentityResourceGroupName" {
  type        = string
  description = "The name of the resource group where the user-assigned identity is located."
}

variable "userAssignedIdentityName" {
  type        = string
  description = "The name of the user-assigned identity."
}

variable "logAnalyticsWorkspaceResourceGroupName" {
  type        = string
  description = "The name of the resource group where the Log Analytics workspace is located."
  default     = ""
}

variable "logAnalyticsWorkspaceName" {
  type        = string
  description = "The name of the Log Analytics workspace."
  default     = ""
}

/// tags
variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource."
  default     = {}
}

/// locals
locals {
  virtual_network_subnet_ids = [
    for subnet in data.azurerm_subnet.subnets : subnet.id
  ]
}
