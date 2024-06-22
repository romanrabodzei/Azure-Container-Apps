/*
.Synopsis
    Bicep template for Key Vault.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.KeyVault/vaults?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240621
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// keyVaultParameters
param location string

param keyVaultName string

/// keyVaultSku
param keyVaultSku string = 'standard'

/// keyVaultConfiguration
param enabledForDeployment bool = false
param enabledForTemplateDeployment bool = true
param enabledForDiskEncryption bool = true
param enableRbacAuthorization bool = true
param enablePurgeProtection bool = true
param enableSoftDelete bool = true
param softDeleteRetentionInDays int = 30
param networkIsolation bool = true

var vaultPrivateDnsZoneName = 'privatelink_vaultcore_azure_net'

/// virtualNetworkParameters
param virtualNetworkResourceGroupName string
param virtualNetworkName string
param virtualNetworkSubnetName string

/// managedIdentityParameters
var KeyVaultSecretsOfficer = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
param userAssignedIdentityResourceGroupName string
param userAssignedIdentityName string

/// keyVaultMonitoring
param logAnalyticsWorkspaceName string = ''
param logAnalyticsWorkspaceResourceGroupName string = ''

/// tags
param tags object = {}

/// resources
resource keyVault_resource 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: toLower(keyVaultName)
  location: location
  tags: tags
  properties: {
    sku: {
      name: keyVaultSku
      family: 'A'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: enabledForDeployment
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enableRbacAuthorization: enableRbacAuthorization
    enablePurgeProtection: enablePurgeProtection
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkIsolation ? 'Deny' : 'Allow'
    }
  }
}

resource managedIdentity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(userAssignedIdentityResourceGroupName)
  name: userAssignedIdentityName
}

resource KeyVaultSecretsOfficer_roleDefinition_resource 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: KeyVaultSecretsOfficer
  scope: subscription()
}

resource KeyVaultSecretsOfficer_roleAssignment_resource 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault_resource
  name: guid(KeyVaultSecretsOfficer_roleDefinition_resource.name, keyVault_resource.name)
  properties: {
    principalType: 'ServicePrincipal'
    principalId: managedIdentity_resource.properties.principalId
    roleDefinitionId: KeyVaultSecretsOfficer_roleDefinition_resource.id
  }
}

resource virtualNetwork_resource 'Microsoft.Network/virtualNetworks@2023-11-01' existing = if (networkIsolation) {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
  resource subnet 'subnets' existing = {
    name: virtualNetworkSubnetName
  }
}

resource vaultPrivateDnsZone_resource 'Microsoft.Network/privateDnsZones@2020-06-01' = if (networkIsolation) {
  name: toLower(replace(vaultPrivateDnsZoneName, '_', '.'))
  location: 'global'
  tags: tags
  properties: {}
}

resource vaultPrivateDnsZone_networkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (networkIsolation) {
  parent: vaultPrivateDnsZone_resource
  name: 'virtual-network-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork_resource.id
    }
    registrationEnabled: false
  }
}

resource vaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = if (networkIsolation) {
  name: toLower('${keyVaultName}-vault-pe')
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: toLower('${keyVaultName}-vault-pe-nic')
    subnet: {
      id: virtualNetwork_resource::subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: toLower('${keyVaultName}-vault-pe')
        properties: {
          privateLinkServiceId: keyVault_resource.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource vaultPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = if (networkIsolation) {
  parent: vaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: toLower(replace(vaultPrivateDnsZoneName, '_', '-'))
        properties: {
          privateDnsZoneId: vaultPrivateDnsZone_resource.id
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
  scope: keyVault_resource
  name: toLower('send-data-to-${logAnalyticsWorkspaceName}')
  properties: {
    workspaceId: logAnalytics_resource.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
