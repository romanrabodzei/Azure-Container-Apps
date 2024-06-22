/*
.Synopsis
    Main Bicep template for Azure Container Apps components.

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240621
*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////// Deployment scope /////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

targetScope = 'subscription'

////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////// Parameters and variables ///////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

@description('The location where the resources will be deployed.')
param deploymentLocation string = deployment().location
@description('The environment where the resources will be deployed.')
@maxLength(6)
param deploymentEnvironment string = 'demo'
@description('The UTC date and time when the deployment is executed.')
param deploymentDate string = utcNow('yyyyMMddHHmm')

/// container apps
@description('Name of the resource group for the Azure Container Apps components.')
param containerAppsResourceGroupName string = 'az-${deploymentEnvironment}-ca-rg'
@description('Name of the Log Analytics workspace.')
param logAnalyticsWorkspaceName string = 'az-${deploymentEnvironment}-ca-law'
param logAnalyticsWorkspaceRetentionInDays int = 30
@description('Daily quota for the Log Analytics workspace in GB. -1 means that there is no cap on the data ingestion.')
param logAnalyticsWorkspaceDailyQuotaGb int = -1
@description('Name of the user-assigned managed identity.')
param userAssignedIdentityName string = 'az-${deploymentEnvironment}-ca-mi'
@description('Name of the storage account.')
param storageAccountName string = 'az${deploymentEnvironment}castg'
@description('Name of the Azure Container Registry.')
param containerRegistryName string = 'az${deploymentEnvironment}caacr'
@description('Name of the application, used for the deployment.')
param applicationName string = 'filebrowser'
param applicationPort int = 8080
@description('Name of the Azure Container Apps.')
param containerAppsName string = 'az-${deploymentEnvironment}-ca'
@description('Name of the Azure Container Apps managed environment.')
param containerAppsManagedEnvironmentName string = 'az-${deploymentEnvironment}-ca-env'

/// virtual network
var virtualNetworkAddressPrefix = '10.0.0.0/22'
var privateEndpointSubnetName = replace(containerAppsResourceGroupName, 'ca-rg', 'pe-subnet')
var privateEndpointSubnetAddressPrefix = [for i in range(0, 4): cidrSubnet(virtualNetworkAddressPrefix, 24, i)]
var privateEndpointSecurityGroupName = '${privateEndpointSubnetName}-nsg'
var containerAppsSubnetName = replace(containerAppsResourceGroupName, 'ca-rg', 'ca-subnet')
var containerAppsSubnetAddressPrefix = [for i in range(0, 2): cidrSubnet(virtualNetworkAddressPrefix, 23, i)]
var containerAppsSecurityGroupName = '${containerAppsSubnetName}-nsg'

@description('Isolation from internet for the resources.')
param networkIsolation bool = false

/// tags
param tagKey string = 'environment'
param tagValue string = deploymentEnvironment
var tags = {
  '${tagKey}': tagValue
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////// Resources //////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

resource resourceGroup_resource 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: toLower(containerAppsResourceGroupName)
  location: deploymentLocation
  tags: tags
}

module newNetwork_module 'resources/virtualNetwork.bicep' = {
  scope: resourceGroup(containerAppsResourceGroupName)
  name: toLower('virtualNetwork-${deploymentDate}')
  params: {
    location: deploymentLocation
    virtualNetworkDeployment: true
    virtualNetworkName: replace(containerAppsResourceGroupName, '-rg', '-vnet')
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    virtualSubnetNames: [
      containerAppsSubnetName
      privateEndpointSubnetName
    ]
    virtualNetworkSubnetAddressPrefixes: [
      containerAppsSubnetAddressPrefix[1]
      privateEndpointSubnetAddressPrefix[1]
    ]
    networkSecurityGroupNames: [
      containerAppsSecurityGroupName
      privateEndpointSecurityGroupName
    ]
    logAnalyticsWorkspaceResourceGroupName: containerAppsResourceGroupName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [logAnalyticsWorkspace_module]
}

module logAnalyticsWorkspace_module './resources/logAnalyticsWorkspace.bicep' = {
  scope: resourceGroup_resource
  name: toLower('logAnalyticsWorkspace-${deploymentDate}')
  params: {
    location: deploymentLocation
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsWorkspaceRetentionInDays: logAnalyticsWorkspaceRetentionInDays
    logAnalyticsWorkspaceDailyQuotaGb: logAnalyticsWorkspaceDailyQuotaGb
    tags: tags
  }
}

module managedIdentity_module './resources/managedIdentity.bicep' = {
  scope: resourceGroup_resource
  name: toLower('managedIdentity-${deploymentDate}')
  params: {
    location: deploymentLocation
    userAssignedIdentityName: userAssignedIdentityName
    tags: tags
  }
}

module storageAccount_module './resources/storageAccount.bicep' = {
  scope: resourceGroup_resource
  name: toLower('storageAccount-${deploymentDate}')
  params: {
    location: deploymentLocation
    storageAccountName: storageAccountName
    networkIsolation: networkIsolation
    virtualNetworkResourceGroupName: containerAppsResourceGroupName
    virtualNetworkName: replace(containerAppsResourceGroupName, '-rg', '-vnet')
    virtualNetworkSubnetName: privateEndpointSubnetName
    userAssignedIdentityResourceGroupName: containerAppsResourceGroupName
    userAssignedIdentityName: userAssignedIdentityName
    logAnalyticsWorkspaceResourceGroupName: containerAppsResourceGroupName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    tags: tags
  }
  dependsOn: [
    newNetwork_module
    managedIdentity_module
  ]
}

module containerRegistry_module './resources/containerRegistry.bicep' = {
  scope: resourceGroup_resource
  name: toLower('containerRegistry-${deploymentDate}')
  params: {
    location: deploymentLocation
    containerRegistryName: containerRegistryName
    applicationName: applicationName
    networkIsolation: networkIsolation
    virtualNetworkResourceGroupName: containerAppsResourceGroupName
    virtualNetworkName: replace(containerAppsResourceGroupName, '-rg', '-vnet')
    virtualNetworkSubnetName: privateEndpointSubnetName
    userAssignedIdentityResourceGroupName: containerAppsResourceGroupName
    userAssignedIdentityName: userAssignedIdentityName
    logAnalyticsWorkspaceResourceGroupName: containerAppsResourceGroupName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    tags: tags
  }
  dependsOn: [
    managedIdentity_module
    newNetwork_module
  ]
}

module containerApps_module './resources/containerApps.bicep' = {
  scope: resourceGroup_resource
  name: toLower('containerAppsEnv-${deploymentDate}')
  params: {
    location: deploymentLocation
    containerAppsName: '${containerAppsName}-${applicationName}'
    containerAppsImage: '${applicationName}:latest'
    containerAppsPort: applicationPort
    containerAppsManagedEnvironmentName: containerAppsManagedEnvironmentName
    containerRegistryResourceGroupName: containerAppsResourceGroupName
    containerRegistryName: containerRegistryName
    virtualNetworkResourceGroupName: containerAppsResourceGroupName
    virtualNetworkName: replace(containerAppsResourceGroupName, '-rg', '-vnet')
    virtualNetworkSubnetName: containerAppsSubnetName
    storageAccountResourceGroupName: containerAppsResourceGroupName
    storageAccountName: storageAccountName
    userAssignedIdentityResourceGroupName: containerAppsResourceGroupName
    userAssignedIdentityName: userAssignedIdentityName
    logAnalyticsWorkspaceResourceGroupName: containerAppsResourceGroupName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    tags: tags
  }
  dependsOn: [
    managedIdentity_module
    newNetwork_module
    storageAccount_module
    containerRegistry_module
  ]
}
