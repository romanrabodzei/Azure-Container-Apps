/*
.Synopsis
    Terraform template for Container Registry.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry

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

variable "containerRegistryName" {
  type        = string
  description = "The name of the container registry."
}

variable "containerRegistrySku" {
  type        = string
  description = "The SKU of the container registry."
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.containerRegistrySku)
    error_message = "The container registry SKU must be Basic, Standard, or Premium."
  }
}

variable "applicationName" {
  type        = string
  description = "The name of the application."
}

variable "applicationImageToImport" {
  type        = string
  description = "The image to import"
}

variable "DockerHubUserName" {
  type        = string
  description = "Docker Hub username."
}

variable "DockerHubToken" {
  type        = string
  description = "Docker Hub token."
}

variable "networkIsolation" {
  type        = bool
  description = "Enable network isolation."
  default     = true
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

variable "virtualNetworkSubnetName" {
  type        = string
  description = "The name of the subnet."
  default     = ""
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
  registryPrivateDnsZoneName = "privatelink_azurecr_io"
  premiumNetworkRuleSet = [{
    default_action  = var.networkIsolation ? "Deny" : "Allow"
    bypass          = ["AzureServices"]
    ip_rule         = []
    virtual_network = []
  }]
}
