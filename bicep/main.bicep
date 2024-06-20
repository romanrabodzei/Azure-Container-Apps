/*
.Synopsis
    Main Bicep template for Azure Container Apps components.

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240619
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
param deploymentEnvironment string = 'poc'
@description('The UTC date and time when the deployment is executed.')
param deploymentDate string = utcNow('yyyyMMddHHmm')

@description('Name of the resource group for the Azure Update Manager components.')
param containerAppsResourceGroupName string = 'az-${deploymentEnvironment}-container-apps-rg'

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
