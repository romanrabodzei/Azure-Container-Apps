/*
.Synopsis
    Terraform template for Container Apps.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240805
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

variable "containerAppsManagedEnvironmentName" {
  type        = string
  description = "The name of the managed environment."
}

variable "containerAppsName" {
  type        = string
  description = "The name of the container app."
}

variable "containerAppsImage" {
  type        = string
  description = "The image of the container app."
}

variable "containerAppsPort" {
  type        = number
  description = "The ports of the container app."
}

variable "containerAppsFolder" {
  type        = list(string)
  description = "The folder of the container app."
}

variable "virtualNetworkResourceGroupName" {
  type        = string
  description = "The resource group name of the virtual network."
}

variable "virtualNetworkName" {
  type        = string
  description = "The name of the virtual network."
}

variable "virtualNetworkSubnetName" {
  type        = string
  description = "The name of the subnet."
}

variable "containerRegistryResourceGroupName" {
  type        = string
  description = "The resource group name of the container registry."
}

variable "containerRegistryName" {
  type        = string
  description = "The name of the container registry."
}

variable "storageAccountResourceGroupName" {
  type        = string
  description = "The resource group name of the storage account."
}

variable "storageAccountName" {
  type        = string
  description = "The name of the storage account."
}

variable "userAssignedIdentityResourceGroupName" {
  type        = string
  description = "The resource group name of the user assigned identity."
}

variable "userAssignedIdentityName" {
  type        = string
  description = "The name of the user assigned identity."
}

variable "logAnalyticsWorkspaceResourceGroupName" {
  type        = string
  description = "The resource group name of the log analytics workspace."
}

variable "logAnalyticsWorkspaceName" {
  type        = string
  description = "The name of the log analytics workspace."
}

/// tags
variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource."
  default     = {}
}