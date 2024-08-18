/*
.Synopsis
    Bicep template for Storage Account.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.Storage/storageAccounts?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240817
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// parameters
param location string

param storageAccountName string
param storageAccountKind string = 'StorageV2'
param storageAccountType string = 'Standard_RAGZRS'
param storageAccountFileShareName array

/// virtualNetworkParameters
param virtualNetworkResourceGroupName string = ''
param virtualNetworkName string = ''
param virtualNetworkSubnetNames array = []

/// managedIdentityParameters
param userAssignedIdentityResourceGroupName string
param userAssignedIdentityName string

/// storageAccountMonitoring
param logAnalyticsWorkspaceResourceGroupName string = ''
param logAnalyticsWorkspaceName string = ''

/// tags
param tags object = {}

/// resources
resource virtualNetwork_resource 'Microsoft.Network/virtualNetworks@2021-05-01' existing = if (!empty(virtualNetworkResourceGroupName) && !empty(virtualNetworkName) && !empty(virtualNetworkSubnetNames)) {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
  resource subnet 'subnets' existing = [
    for virtualNetworkSubnetName in virtualNetworkSubnetNames: {
      name: virtualNetworkSubnetName
    }
  ]
}

var virtualNetworkRules = [
  for (virtualNetworkSubnetName, item) in virtualNetworkSubnetNames: {
    id: virtualNetwork_resource::subnet[item].id
    action: 'Allow'
  }
]

output virtualNetworkRules array = virtualNetworkRules

resource storageAccount_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower(storageAccountName)
  location: location
  tags: tags
  sku: {
    name: storageAccountType
  }
  kind: storageAccountKind
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: !empty(virtualNetworkResourceGroupName) && !empty(virtualNetworkName) && !empty(virtualNetworkSubnetNames)
        ? virtualNetworkRules
        : []
    }
  }
  resource fileshare 'fileServices' = {
    name: 'default'
    properties: {}
    resource default 'shares' = [
      for item in storageAccountFileShareName: {
        name: item
        properties: {
          accessTier: 'Hot'
          enabledProtocols: 'SMB'
          shareQuota: 1024
        }
      }
    ]
  }
}

resource managedIdentity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(userAssignedIdentityResourceGroupName)
  name: userAssignedIdentityName
}

var StorageBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageBlobDataContributor_roleDefinition_resource 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: StorageBlobDataContributor
  scope: subscription()
}

resource storageBlobDataContributor_roleAssignment_resource 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount_resource
  name: guid(storageBlobDataContributor_roleDefinition_resource.name, storageAccount_resource.name)
  properties: {
    principalType: 'ServicePrincipal'
    principalId: managedIdentity_resource.properties.principalId
    roleDefinitionId: storageBlobDataContributor_roleDefinition_resource.id
  }
}

var StorageFileDataSMBShareContributor = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'

resource StorageFileDataSMBShareContributor_roleDefinition_resource 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: StorageFileDataSMBShareContributor
  scope: subscription()
}

resource StorageFileDataSMBShareContributor_roleAssignment_resource 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount_resource
  name: guid(StorageFileDataSMBShareContributor_roleDefinition_resource.name, storageAccount_resource.name)
  properties: {
    principalType: 'ServicePrincipal'
    principalId: managedIdentity_resource.properties.principalId
    roleDefinitionId: StorageFileDataSMBShareContributor_roleDefinition_resource.id
  }
}

resource logAnalytics_resource 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = if (!empty(logAnalyticsWorkspaceName)) {
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
  name: logAnalyticsWorkspaceName
}

resource send_data_to_logAnalyticsWorkspace 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceName)) {
  scope: storageAccount_resource
  name: toLower('send-data-to-${logAnalyticsWorkspaceName}')
  properties: {
    workspaceId: logAnalytics_resource.id
    metrics: [
      {
        category: 'Capacity'
        enabled: true
      }
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

/// output
output storageAccountId string = storageAccount_resource.id
