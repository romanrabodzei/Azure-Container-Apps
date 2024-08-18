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

variable "containerRegistry" {
  type        = string
  description = "The name of the container registry."
}


variable "containerAppsFolder" {
  type        = list(string)
  description = "The folder of the container app."
}

variable "cpuCore" {
  description = "Number of CPU cores the container can use. Can be with a maximum of two decimals."
  type        = string
  default     = "1.0"
  validation {
    condition     = contains(["0.25", "0.5", "0.75", "1.0", "1.25", "1.5", "1.75", "2.0"], var.cpuCore)
    error_message = "CPU core must be one of the allowed values: 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0."
  }
}

variable "memorySize" {
  description = "Amount of memory (in gibibytes, GiB) allocated to the container up to 4GiB. Can be with a maximum of two decimals. Ratio with CPU cores must be equal to 2."
  type        = string
  default     = "2.0"
  validation {
    condition     = contains(["0.5", "1.0", "1.5", "2.0", "3.0", "3.5", "4.0"], var.memorySize)
    error_message = "Memory size must be one of the allowed values: 0.5, 1.0, 1.5, 2.0, 3.0, 3.5, 4.0."
  }
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