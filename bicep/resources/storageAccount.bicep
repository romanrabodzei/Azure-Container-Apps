/*
.Synopsis
    Bicep template for Storage Account.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.Storage/storageAccounts?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240707
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// parameters
param location string

param storageAccountName string
param storageAccountKind string = 'StorageV2'
param storageAccountType string = 'Standard_RAGZRS'
param storageAccountFileShareName string = 'fileshare'

/// virtualNetworkParameters
param networkIsolation bool = false
param virtualNetworkResourceGroupName string = ''
param virtualNetworkName string = ''
param virtualNetworkSubnetName string = ''
var fileSharePrivateDnsZoneName = 'privatelink_file_core_windows_net'
var queuePrivateDnsZoneName = 'privatelink_queue_core_windows_net'

/// managedIdentityParameters
param userAssignedIdentityResourceGroupName string
param userAssignedIdentityName string

/// storageAccountMonitoring
param logAnalyticsWorkspaceResourceGroupName string = ''
param logAnalyticsWorkspaceName string = ''

/// tags
param tags object = {}

/// resources
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
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkIsolation ? 'Deny' : 'Allow'
    }
  }
  resource fileshare 'fileServices' = {
    name: 'default'
    properties: {}
    resource default 'shares' = {
      name: storageAccountFileShareName
      properties: {
        accessTier: 'Hot'
        enabledProtocols: 'SMB'
        shareQuota: 1024
      }
    }
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

resource virtualNetwork_resource 'Microsoft.Network/virtualNetworks@2023-11-01' existing = if (networkIsolation) {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
  resource subnet 'subnets' existing = {
    name: virtualNetworkSubnetName
  }
}

resource fileSharePrivateDnsZone_resource 'Microsoft.Network/privateDnsZones@2020-06-01' = if (networkIsolation) {
  name: toLower(replace(fileSharePrivateDnsZoneName, '_', '.'))
  location: 'global'
  tags: tags
  properties: {}
}

resource fileSharePrivateDnsZone_networkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (networkIsolation) {
  parent: fileSharePrivateDnsZone_resource
  name: 'virtual-network-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork_resource.id
    }
    registrationEnabled: false
  }
}

resource fileSharePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = if (networkIsolation) {
  name: toLower('${storageAccountName}-file-pe')
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: toLower('${storageAccountName}-file-pe-nic')
    subnet: {
      id: virtualNetwork_resource::subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: toLower('${storageAccountName}-file-pe')
        properties: {
          privateLinkServiceId: storageAccount_resource.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

resource fileSharePrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = if (networkIsolation) {
  parent: fileSharePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: toLower(replace(fileSharePrivateDnsZoneName, '_', '-'))
        properties: {
          privateDnsZoneId: fileSharePrivateDnsZone_resource.id
        }
      }
    ]
  }
}

resource queuePrivateDnsZone_resource 'Microsoft.Network/privateDnsZones@2020-06-01' = if (networkIsolation) {
  name: toLower(replace(queuePrivateDnsZoneName, '_', '.'))
  location: 'global'
  tags: tags
  properties: {}
}

resource queuePrivateDnsZone_networkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (networkIsolation) {
  parent: queuePrivateDnsZone_resource
  name: 'virtual-network-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork_resource.id
    }
    registrationEnabled: false
  }
}

resource queuePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = if (networkIsolation) {
  name: toLower('${storageAccountName}-queue-pe')
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: toLower('${storageAccountName}-queue-pe-nic')
    subnet: {
      id: virtualNetwork_resource::subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: toLower('${storageAccountName}-queue-pe')
        properties: {
          privateLinkServiceId: storageAccount_resource.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }
}

resource queuePrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = if (networkIsolation) {
  parent: queuePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: toLower(replace(queuePrivateDnsZoneName, '_', '-'))
        properties: {
          privateDnsZoneId: queuePrivateDnsZone_resource.id
        }
      }
    ]
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
