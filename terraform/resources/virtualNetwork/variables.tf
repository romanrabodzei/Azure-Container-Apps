/*
.Synopsis
    Terraform template for Virtual Network.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/virtualNetworks?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240817
*/

/// variable
variable "deploymentResourceGroupName" {
  type        = string
  description = "Deployment resource group name."
}

variable "deploymentLocation" {
  type        = string
  description = "The location where the resources will be deployed."
}

variable "virtualNetworkName" {
  type        = string
  description = "The name of the virtual network."
}

variable "virtualNetworkAddressPrefix" {
  type        = string
  description = "The address prefix for the virtual network."
}

variable "virtualSubnetNames" {
  type        = list(string)
  description = "The names of the subnets."
}

variable "virtualNetworkSubnetAddressPrefixes" {
  type        = list(string)
  description = "The address prefixes for the subnets."
}

variable "networkSecurityGroupNames" {
  type        = list(string)
  description = "The names of the network security groups."
}

variable "logAnalyticsWorkspaceName" {
  type        = string
  description = "The name of the Log Analytics workspace."
  default     = ""
}
variable "logAnalyticsWorkspaceResourceGroupName" {
  type        = string
  description = "The name of the Log Analytics workspace resource group."
  default     = ""
}

/// tags
variable "tags" {
  type    = map(string)
  default = {}
}

/// locals
locals {
  networkSecurityGroups = [
    "containerApps",
    # "infrastructure"
  ]
  securityRules = {
    containerApps = [{
      name : "AllowAnyHTTPSInbound"
      priority : 100
      protocol : "Tcp"
      sourcePortRange : "*"
      destinationPortRange : "443"
      sourceAddressPrefix : "*"
      destinationAddressPrefix : "*"
      access : "Allow"
      direction : "Inbound"
      sourcePortRanges : []
      destinationPortRanges : []
      sourceAddressPrefixes : []
      destinationAddressPrefixes : []
    }]
    # infrastructure = []
  }
}
