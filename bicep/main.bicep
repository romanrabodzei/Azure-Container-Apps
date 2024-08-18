/*
.Synopsis
    Main Bicep template for Azure Container Apps components.

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240817
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
param deploymentEnvironment string = 'bcp'

@description('The UTC date and time when the deployment is executed.')
param deploymentDate string = utcNow('yyyyMMddHHmm')

/// container apps
@description('Name of the resource group for the Azure Container Apps components.')
param containerAppsResourceGroupName string = 'az-${deploymentEnvironment}-capp-rg'

@description('Name of the Log Analytics workspace.')
param logAnalyticsWorkspaceName string = 'az-${deploymentEnvironment}-capp-law'
@description('Retention period for the Log Analytics workspace in days. 30 days is free.')
param logAnalyticsWorkspaceRetentionInDays int = 30
@description('Daily quota for the Log Analytics workspace in GB. -1 means that there is no cap on the data ingestion.')
param logAnalyticsWorkspaceDailyQuotaGb int = -1

@description('Name of the user-assigned managed identity.')
param userAssignedIdentityName string = 'az-${deploymentEnvironment}-capp-mi'

@description('Name of the storage account.')
param storageAccountName string = 'az${deploymentEnvironment}cappstg'

@description('Name of the application, dockerhub url, port and persistent volume, used for the deployment.')
var applicationName = 'filebrowser'
var applicationImageToPull = 'docker.io/hurlenko'
var applicationPort = 8080
var applicationFolders = ['data']

@description('Name of the Azure Container Apps.')
param containerAppsName string = 'az-${deploymentEnvironment}-capp'
@description('Name of the Azure Container Apps managed environment.')
param containerAppsManagedEnvironmentName string = 'az-${deploymentEnvironment}-capp-env'

/// virtual network
param virtualNetworkName string = 'az-${deploymentEnvironment}-capp-vnet'
var virtualNetworkAddressPrefix = '10.0.0.0/22'

// uncomment the following lines and lines in the code (121, 125, 129, 148) if you want to deploy a additional subnet.
// var infrastructureSubnetName = replace(containerAppsResourceGroupName, 'capp-rg', 'infra-subnet')
// var infrastructureSubnetAddressPrefix = [for i in range(0, 4): cidrSubnet(virtualNetworkAddressPrefix, 24, i)]
// var infrastructureSecurityGroupName = '${infrastructureSubnetName}-nsg'

var containerAppsSubnetName = replace(containerAppsResourceGroupName, 'capp-rg', 'capp-subnet')
var containerAppsSubnetAddressPrefix = [for i in range(0, 2): cidrSubnet(virtualNetworkAddressPrefix, 23, i)]
var containerAppsSecurityGroupName = '${containerAppsSubnetName}-nsg'

/// tags
param tagValue string = deploymentEnvironment
param tags object = {
  project: 'container apps'
  environment: tagValue
  'deployment date': utcNow('yyyy-MM-dd')
  'review date': dateTimeAdd(utcNow('yyyy-MM-dd'), 'P6M', 'yyyy-MM-dd')
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////// Resources //////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////

resource resourceGroup_resource 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: toLower(containerAppsResourceGroupName)
  location: deploymentLocation
  tags: tags
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

module network_module 'resources/virtualNetwork.bicep' = {
  scope: resourceGroup(resourceGroup_resource.name)
  name: toLower('virtualNetwork-${deploymentDate}')
  params: {
    location: deploymentLocation
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    virtualSubnetNames: [
      containerAppsSubnetName
      // infrastructureSubnetName
    ]
    virtualNetworkSubnetAddressPrefixes: [
      containerAppsSubnetAddressPrefix[1]
      // infrastructureSubnetAddressPrefix[1]
    ]
    networkSecurityGroupNames: [
      containerAppsSecurityGroupName
      // infrastructureSecurityGroupName
    ]
    logAnalyticsWorkspaceResourceGroupName: resourceGroup_resource.name
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [logAnalyticsWorkspace_module]
}

module storageAccount_module './resources/storageAccount.bicep' = {
  scope: resourceGroup_resource
  name: toLower('storageAccount-${deploymentDate}')
  params: {
    location: deploymentLocation
    storageAccountName: storageAccountName
    storageAccountFileShareName: applicationFolders
    virtualNetworkResourceGroupName: resourceGroup_resource.name
    virtualNetworkName: virtualNetworkName
    virtualNetworkSubnetNames: [
      containerAppsSubnetName
      // infrastructureSubnetName
    ]
    userAssignedIdentityResourceGroupName: resourceGroup_resource.name
    userAssignedIdentityName: userAssignedIdentityName
    logAnalyticsWorkspaceResourceGroupName: resourceGroup_resource.name
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    tags: tags
  }
  dependsOn: [
    network_module
    managedIdentity_module
  ]
}

module containerApps_module './resources/containerApps.bicep' = {
  scope: resourceGroup_resource
  name: toLower('containerAppsEnv-${deploymentDate}')
  params: {
    location: deploymentLocation
    containerAppsName: '${containerAppsName}-${applicationName}'
    containerAppsImage: '${applicationName}:latest'
    containerRegistry: applicationImageToPull
    containerAppsPort: applicationPort
    containerAppsFolders: applicationFolders
    containerAppsManagedEnvironmentName: containerAppsManagedEnvironmentName
    virtualNetworkResourceGroupName: resourceGroup_resource.name
    virtualNetworkName: virtualNetworkName
    virtualNetworkSubnetName: containerAppsSubnetName
    storageAccountResourceGroupName: resourceGroup_resource.name
    storageAccountName: storageAccountName
    userAssignedIdentityResourceGroupName: resourceGroup_resource.name
    userAssignedIdentityName: userAssignedIdentityName
    logAnalyticsWorkspaceResourceGroupName: resourceGroup_resource.name
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    tags: tags
  }
  dependsOn: [
    managedIdentity_module
    network_module
    storageAccount_module
  ]
}
