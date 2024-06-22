/*
.Synopsis
    Bicep template for Container Registry.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.ContainerRegistry/registries?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240621
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// containerRegistryParameters
param location string

param containerRegistryName string

param applicationName string

/// containerRegistrySku
param containerRegistrySku string = 'Premium'

/// containerRegistryConfiguration
param networkIsolation bool = true

var registryPrivateDnsZoneName = 'privatelink_azurecr_io'

/// virtualNetworkParameters
param virtualNetworkResourceGroupName string
param virtualNetworkName string
param virtualNetworkSubnetName string

/// managedIdentityParameters
var containerRegistryACRRepositoryContributor = '2efddaa5-3f1f-4df3-97df-af3f13818f4c'
param userAssignedIdentityResourceGroupName string
param userAssignedIdentityName string

/// containerRegistryMonitoring
param logAnalyticsWorkspaceName string = ''
param logAnalyticsWorkspaceResourceGroupName string = ''

/// tags
param tags object = {}

/// resources
resource containerRegistry_resource 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: toLower(containerRegistryName)
  location: location
  tags: tags
  sku: {
    name: containerRegistrySku
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId(userAssignedIdentityResourceGroupName, 'Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)}': {}
    }
  }
  properties: {
    adminUserEnabled: true
    networkRuleSet: {
      defaultAction: networkIsolation ? 'Deny' : 'Allow'
    }
    publicNetworkAccess: networkIsolation ? 'Disabled' : 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: toLower(replace(resourceGroup().name, '-rg', 'ds-azcli'))
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId(userAssignedIdentityResourceGroupName, 'Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)}': {}
    }
  }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.9.0'
    environmentVariables: [
      {
        name: 'containerRegistryName'
        value: toLower(containerRegistryName)
      }
      {
        name: 'applicationName'
        value: applicationName
      }
    ]
    scriptContent: '''
    az acr import --name $containerRegistryName --source docker.io/hurlenko/filebrowser:latest --image $applicationName:latest
    az acr artifact-streaming update --name $containerRegistryName --repository $applicationName --enable-streaming true
    '''
    timeout: 'PT1H'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
  }
  dependsOn: [containerRegistry_resource, containerRegistryACRRepositoryContributor_roleAssignment_resource]
}

resource managedIdentity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(userAssignedIdentityResourceGroupName)
  name: userAssignedIdentityName
}

resource containerRegistryACRRepositoryContributor_roleDefinition_resource 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: containerRegistryACRRepositoryContributor
  scope: subscription()
}

resource containerRegistryACRRepositoryContributor_roleAssignment_resource 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry_resource
  name: guid(containerRegistryACRRepositoryContributor_roleDefinition_resource.name, containerRegistry_resource.name)
  properties: {
    principalType: 'ServicePrincipal'
    principalId: managedIdentity_resource.properties.principalId
    roleDefinitionId: containerRegistryACRRepositoryContributor_roleDefinition_resource.id
  }
}

resource virtualNetwork_resource 'Microsoft.Network/virtualNetworks@2023-11-01' existing = if (networkIsolation) {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
  resource subnet 'subnets' existing = {
    name: virtualNetworkSubnetName
  }
}

resource registryPrivateDnsZone_resource 'Microsoft.Network/privateDnsZones@2020-06-01' = if (networkIsolation) {
  name: toLower(replace(registryPrivateDnsZoneName, '_', '.'))
  location: 'global'
  tags: tags
  properties: {}
}

resource registryPrivateDnsZone_networkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (networkIsolation) {
  parent: registryPrivateDnsZone_resource
  name: 'virtual-network-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork_resource.id
    }
    registrationEnabled: false
  }
}

resource registryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = if (networkIsolation) {
  name: toLower('${containerRegistryName}-registry-pe')
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: toLower('${containerRegistryName}-registry-pe-nic')
    subnet: {
      id: virtualNetwork_resource::subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: toLower('${containerRegistryName}-registry-pe')
        properties: {
          privateLinkServiceId: containerRegistry_resource.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

resource fileSharePrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = if (networkIsolation) {
  parent: registryPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: toLower(replace(registryPrivateDnsZoneName, '_', '-'))
        properties: {
          privateDnsZoneId: registryPrivateDnsZone_resource.id
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
  scope: containerRegistry_resource
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

/// output
output containerRegistryId string = containerRegistry_resource.id
