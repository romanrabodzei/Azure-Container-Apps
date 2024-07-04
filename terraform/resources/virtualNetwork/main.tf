/*
.Synopsis
    Bicep template for Virtual Network.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/virtualNetworks?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240703
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

variable "tags" {
  type    = map(string)
  default = {}
}

/// locals
locals {
  networkSecurityGroups = [
    "containerApps",
    "privateEndpoints"
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
    privateEndpoints = []
  }
}

/// resource
data "azurerm_log_analytics_workspace" "this_resource" {
  count               = length(var.logAnalyticsWorkspaceName) > 0 && length(var.logAnalyticsWorkspaceResourceGroupName) > 0 ? 1 : 0
  name                = var.logAnalyticsWorkspaceName
  resource_group_name = var.logAnalyticsWorkspaceResourceGroupName
}

resource "azurerm_virtual_network" "this_resource" {
  name                = var.virtualNetworkName
  location            = var.deploymentLocation
  resource_group_name = var.deploymentResourceGroupName
  address_space       = [var.virtualNetworkAddressPrefix]
  tags                = var.tags
}

resource "azurerm_subnet" "this_resource" {
  count                = length(var.virtualSubnetNames)
  name                 = lower(var.virtualSubnetNames[count.index])
  resource_group_name  = var.deploymentResourceGroupName
  virtual_network_name = var.virtualNetworkName
  address_prefixes     = [var.virtualNetworkSubnetAddressPrefixes[count.index]]
}

resource "azurerm_monitor_diagnostic_setting" "send_data_to_logAnalyticsWorkspace_virtualNetwork" {
  count                      = length(var.logAnalyticsWorkspaceName) > 0 && length(var.logAnalyticsWorkspaceResourceGroupName) > 0 ? 1 : 0
  name                       = lower("send-data-to-${var.logAnalyticsWorkspaceName}")
  target_resource_id         = azurerm_virtual_network.this_resource.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this_resource[0].id
  enabled_log {
    category_group = "allLogs"
  }
  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_network_security_group" "this_resource" {
  count               = length(var.networkSecurityGroupNames)
  name                = lower(var.networkSecurityGroupNames[count.index])
  location            = var.deploymentLocation
  resource_group_name = var.deploymentResourceGroupName
  tags                = var.tags
  dynamic "security_rule" {
    for_each = toset(local.securityRules[local.networkSecurityGroups[count.index]])
    content {
      name                         = security_rule.value["name"]
      priority                     = security_rule.value["priority"]
      protocol                     = security_rule.value["protocol"]
      source_port_range            = security_rule.value["sourcePortRange"]
      destination_port_range       = security_rule.value["destinationPortRange"]
      source_address_prefix        = security_rule.value["sourceAddressPrefix"]
      destination_address_prefix   = security_rule.value["destinationAddressPrefix"]
      access                       = security_rule.value["access"]
      direction                    = security_rule.value["direction"]
      source_port_ranges           = security_rule.value["sourcePortRanges"]
      destination_port_ranges      = security_rule.value["destinationPortRanges"]
      source_address_prefixes      = security_rule.value["sourceAddressPrefixes"]
      destination_address_prefixes = security_rule.value["destinationAddressPrefixes"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  count                     = length(var.networkSecurityGroupNames)
  subnet_id                 = azurerm_subnet.this_resource[count.index].id
  network_security_group_id = azurerm_network_security_group.this_resource[count.index].id
}

resource "azurerm_monitor_diagnostic_setting" "send_data_to_logAnalyticsWorkspace_networkSecurityGroup" {
  for_each                   = { for i, networkSecurityGroup in local.networkSecurityGroups : i => networkSecurityGroup if length(var.logAnalyticsWorkspaceName) > 0 && length(var.logAnalyticsWorkspaceResourceGroupName) > 0 }
  name                       = lower("send-data-to-${var.logAnalyticsWorkspaceName}")
  target_resource_id         = each.value.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this_resource[0].id
  enabled_log {
    category_group = "allLogs"
  }
  metric {
    category = "AllMetrics"
  }
}

/// output
output "virtualNetworkId" {
  value = azurerm_virtual_network.this_resource.id
}
