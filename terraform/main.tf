/*
.Synopsis
    Main Terraform template for Azure Container Apps components.

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240817
*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////// Locals and variables ///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

locals {
  deploymentDate                      = formatdate("yyyyMMddHHmm", timestamp())
  containerAppsResourceGroupName      = var.containerAppsResourceGroupName == "" ? "az-${var.deploymentEnvironment}-capp-rg" : var.containerAppsResourceGroupName
  logAnalyticsWorkspaceName           = var.logAnalyticsWorkspaceName == "" ? "az-${var.deploymentEnvironment}-capp-law" : var.logAnalyticsWorkspaceName
  userAssignedIdentityName            = var.userAssignedIdentityName == "" ? "az-${var.deploymentEnvironment}-capp-mi" : var.userAssignedIdentityName
  storageAccountName                  = var.storageAccountName == "" ? "az${var.deploymentEnvironment}cappstg" : var.storageAccountName
  containerAppsName                   = var.containerAppsName == "" ? "az-${var.deploymentEnvironment}-capp" : var.containerAppsName
  containerAppsManagedEnvironmentName = var.containerAppsManagedEnvironmentName == "" ? "az-${var.deploymentEnvironment}-capp-env" : var.containerAppsManagedEnvironmentName
  virtualNetworkName                  = var.virtualNetworkName == "" ? "az-${var.deploymentEnvironment}-capp-vnet" : var.virtualNetworkName
  # infrastructureSubnetName            = replace(local.containerAppsResourceGroupName, "capp-rg", "pe-subnet")
  # infrastructureSubnetAddressPrefix   = cidrsubnet(var.virtualNetworkAddressPrefix, 2, 3)
  # infrastructureSecurityGroupName     = "${local.infrastructureSubnetName}-nsg"
  containerAppsSubnetName          = replace(local.containerAppsResourceGroupName, "capp-rg", "capp-subnet")
  containerAppsSubnetAddressPrefix = cidrsubnet(var.virtualNetworkAddressPrefix, 1, 0)
  containerAppsSecurityGroupName   = "${local.containerAppsSubnetName}-nsg"
  tagValue                         = var.tagValue == "" ? var.deploymentEnvironment : var.tagValue
  tags = {
    "project"         = "container apps"
    "environment"     = local.tagValue
    "deployment date" = formatdate("YYYY-MM-DD", timestamp())
    "review date"     = formatdate("YYYY-MM-DD", timeadd(timestamp(), "4380h"))
  }
}

variable "deploymentLocation" {
  type        = string
  description = "The location where the resources will be deployed."
  default     = "West Europe"
}

variable "deploymentEnvironment" {
  type        = string
  description = "The environment where the resources will be deployed."
  default     = "tf"
}

variable "containerAppsResourceGroupName" {
  type        = string
  description = "The name of the resource group where the Azure Update Manager resources will be deployed."
  default     = ""
}

variable "logAnalyticsWorkspaceName" {
  type        = string
  description = "The name of the Log Analytics workspace."
  default     = ""
}

variable "logAnalyticsWorkspaceRetentionInDays" {
  type        = number
  description = "The retention period for the Log Analytics workspace."
  default     = 30
}

variable "logAnalyticsWorkspaceDailyQuotaGb" {
  type        = number
  description = "Daily quota for the Log Analytics workspace in GB. -1 means that there is no cap on the data ingestion."
  default     = -1
}

variable "userAssignedIdentityName" {
  type        = string
  description = "The name of the user-assigned identity."
  default     = ""
}

variable "storageAccountName" {
  type        = string
  description = "The name of the storage account."
  default     = ""
}

variable "applicationName" {
  type        = string
  description = "The name of the application."
  default     = "filebrowser"
}

variable "applicationImageToPull" {
  type        = string
  description = "The image to import."
  default     = "docker.io/hurlenko"
}

variable "applicationPort" {
  type        = number
  description = "The port on which the application listens."
  default     = 8080
}

variable "applicationFolder" {
  type        = list(string)
  description = "The folder where the application is stored."
  default     = ["data"]
}

variable "containerAppsName" {
  type        = string
  description = "The name of the Azure Container Apps."
  default     = ""
}

variable "containerAppsManagedEnvironmentName" {
  type        = string
  description = "The name of the managed environment."
  default     = ""
}

variable "virtualNetworkName" {
  type        = string
  description = "The name of the virtual network."
  default     = ""
}

variable "virtualNetworkAddressPrefix" {
  type        = string
  description = "The address prefix for the virtual network."
  default     = "10.0.0.0/22"
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

module "logAnalyticsWorkspace_module" {
  source                               = "./resources/logAnalyticsWorkspace"
  deploymentResourceGroupName          = azurerm_resource_group.this_resource.name
  deploymentLocation                   = var.deploymentLocation
  logAnalyticsWorkspaceName            = local.logAnalyticsWorkspaceName
  logAnalyticsWorkspaceRetentionInDays = var.logAnalyticsWorkspaceRetentionInDays
  logAnalyticsWorkspaceDailyQuotaGb    = var.logAnalyticsWorkspaceDailyQuotaGb
  tags                                 = local.tags
}

module "managedIdentity_module" {
  source                      = "./resources/managedIdentity"
  deploymentResourceGroupName = azurerm_resource_group.this_resource.name
  deploymentLocation          = var.deploymentLocation
  userAssignedIdentityName    = local.userAssignedIdentityName
  tags                        = local.tags
}

module "network_module" {
  source                                 = "./resources/virtualNetwork"
  deploymentResourceGroupName            = azurerm_resource_group.this_resource.name
  deploymentLocation                     = var.deploymentLocation
  virtualNetworkName                     = local.virtualNetworkName
  virtualNetworkAddressPrefix            = var.virtualNetworkAddressPrefix
  virtualSubnetNames                     = [local.containerAppsSubnetName]          #, local.infrastructureSubnetName]
  virtualNetworkSubnetAddressPrefixes    = [local.containerAppsSubnetAddressPrefix] #, local.infrastructureSubnetAddressPrefix]
  networkSecurityGroupNames              = [local.containerAppsSecurityGroupName]   #, local.infrastructureSecurityGroupName]
  logAnalyticsWorkspaceResourceGroupName = local.containerAppsResourceGroupName
  logAnalyticsWorkspaceName              = local.logAnalyticsWorkspaceName
  tags                                   = local.tags
  depends_on                             = [module.logAnalyticsWorkspace_module]
}

module "storageAccount_module" {
  source                                 = "./resources/storageAccount"
  deploymentResourceGroupName            = azurerm_resource_group.this_resource.name
  deploymentLocation                     = var.deploymentLocation
  storageAccountName                     = local.storageAccountName
  storageAccountFileShareName            = var.applicationFolder
  virtualNetworkResourceGroupName        = azurerm_resource_group.this_resource.name
  virtualNetworkName                     = local.virtualNetworkName
  virtualNetworkSubnetNames              = [local.containerAppsSubnetName] #, local.infrastructureSubnetName]
  userAssignedIdentityResourceGroupName  = azurerm_resource_group.this_resource.name
  userAssignedIdentityName               = local.userAssignedIdentityName
  logAnalyticsWorkspaceResourceGroupName = azurerm_resource_group.this_resource.name
  logAnalyticsWorkspaceName              = local.logAnalyticsWorkspaceName
  tags                                   = local.tags
  depends_on = [
    module.logAnalyticsWorkspace_module,
    module.managedIdentity_module,
    module.network_module
  ]
}
module "containerApps_module" {
  source                                 = "./resources/containerApps"
  deploymentLocation                     = var.deploymentLocation
  deploymentResourceGroupName            = azurerm_resource_group.this_resource.name
  containerAppsName                      = local.containerAppsName
  containerAppsImage                     = "${var.applicationName}:latest"
  containerRegistry                      = var.applicationImageToPull
  containerAppsPort                      = var.applicationPort
  containerAppsFolder                    = var.applicationFolder
  containerAppsManagedEnvironmentName    = local.containerAppsManagedEnvironmentName
  userAssignedIdentityResourceGroupName  = azurerm_resource_group.this_resource.name
  userAssignedIdentityName               = local.userAssignedIdentityName
  storageAccountResourceGroupName        = azurerm_resource_group.this_resource.name
  storageAccountName                     = local.storageAccountName
  virtualNetworkResourceGroupName        = azurerm_resource_group.this_resource.name
  virtualNetworkName                     = local.virtualNetworkName
  virtualNetworkSubnetName               = local.containerAppsSubnetName
  logAnalyticsWorkspaceResourceGroupName = azurerm_resource_group.this_resource.name
  logAnalyticsWorkspaceName              = local.logAnalyticsWorkspaceName
  tags                                   = local.tags
  depends_on = [
    module.logAnalyticsWorkspace_module,
    module.managedIdentity_module,
    module.network_module,
    module.storageAccount_module
  ]
}
