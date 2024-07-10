/*
.Synopsis
    Main Bicep template for Azure Container Apps components.

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240710
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
  containerRegistryName               = var.containerRegistryName == "" ? "az${var.deploymentEnvironment}cappacr" : var.containerRegistryName
  containerAppsName                   = var.containerAppsName == "" ? "az-${var.deploymentEnvironment}-capp" : var.containerAppsName
  containerAppsManagedEnvironmentName = var.containerAppsManagedEnvironmentName == "" ? "az-${var.deploymentEnvironment}-capp-env" : var.containerAppsManagedEnvironmentName
  virtualNetworkName                  = var.virtualNetworkName == "" ? "az-${var.deploymentEnvironment}-capp-vnet" : var.virtualNetworkName
  privateEndpointSubnetName           = replace(local.containerAppsResourceGroupName, "capp-rg", "pe-subnet")
  privateEndpointSubnetAddressPrefix  = cidrsubnet(var.virtualNetworkAddressPrefix, 2, 3)
  privateEndpointSecurityGroupName    = "${local.privateEndpointSubnetName}-nsg"
  containerAppsSubnetName             = replace(local.containerAppsResourceGroupName, "capp-rg", "capp-subnet")
  containerAppsSubnetAddressPrefix    = cidrsubnet(var.virtualNetworkAddressPrefix, 1, 0)
  containerAppsSecurityGroupName      = "${local.containerAppsSubnetName}-nsg"
  tagValue                            = var.tagValue == "" ? var.deploymentEnvironment : var.tagValue
  tags                                = { "${var.tagKey}" : local.tagValue }
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

variable "containerRegistryName" {
  type        = string
  description = "The name of the container registry."
  default     = ""
}

variable "applicationName" {
  type        = string
  description = "The name of the application."
  default     = "filebrowser"
}

variable "applicationImageToImport" {
  type        = string
  description = "The image to import."
  default     = "docker.io/hurlenko/filebrowser:latest"
}

variable "DockerHubUserName" {
  type        = string
  description = "Docker Hub username."
  sensitive   = true
}

variable "DockerHubToken" {
  type        = string
  description = "Docker Hub token."
  sensitive   = true
}

variable "applicationPort" {
  type        = number
  description = "The port on which the application listens."
  default     = 8080
}

variable "applicationFolder" {
  type        = string
  description = "The folder where the application is stored."
  default     = "data"
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

variable "networkIsolation" {
  type        = bool
  description = "Isolation from internet for the resources."
  default     = false
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
  virtualSubnetNames                     = [local.containerAppsSubnetName, local.privateEndpointSubnetName]
  virtualNetworkSubnetAddressPrefixes    = [local.containerAppsSubnetAddressPrefix, local.privateEndpointSubnetAddressPrefix]
  networkSecurityGroupNames              = [local.containerAppsSecurityGroupName, local.privateEndpointSecurityGroupName]
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
  networkIsolation                       = var.networkIsolation
  virtualNetworkResourceGroupName        = azurerm_resource_group.this_resource.name
  virtualNetworkName                     = local.virtualNetworkName
  virtualNetworkSubnetName               = local.privateEndpointSubnetName
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

module "containerRegistry_module" {
  source                                 = "./resources/containerRegistry"
  deploymentResourceGroupName            = azurerm_resource_group.this_resource.name
  deploymentLocation                     = var.deploymentLocation
  containerRegistryName                  = local.containerRegistryName
  applicationName                        = var.applicationName
  applicationImageToImport               = var.applicationImageToImport
  DockerHubUserName                      = base64encode(var.DockerHubUserName)
  DockerHubToken                         = base64encode(var.DockerHubToken)
  networkIsolation                       = var.networkIsolation
  virtualNetworkResourceGroupName        = azurerm_resource_group.this_resource.name
  virtualNetworkName                     = local.virtualNetworkName
  virtualNetworkSubnetName               = local.containerAppsSubnetName
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
