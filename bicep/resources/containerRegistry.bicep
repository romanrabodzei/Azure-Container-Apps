/*
.Synopsis
    Bicep template for Container Registry.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.ContainerRegistry/registries?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240710
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// parameters
param location string

param containerRegistryName string
@allowed([
  'Basic'
  'Premium'
  'Standard'
])
param containerRegistrySku string = 'Standard'

param applicationName string
param applicationImageToImport string
param DockerHubUserName string
param DockerHubToken string

/// virtualNetworkParameters
param networkIsolation bool = true
param virtualNetworkResourceGroupName string
param virtualNetworkName string
param virtualNetworkSubnetName string
var registryPrivateDnsZoneName = 'privatelink_azurecr_io'
var containerRegistryPremiumProperties = {
  adminUserEnabled: true
  networkRuleSet: {
    defaultAction: 'Deny'
  }
  publicNetworkAccess: 'Disabled'
  networkRuleBypassOptions: 'AzureServices'
}
var containerRegistryStandardProperties = {
  adminUserEnabled: true
}

/// managedIdentityParameters
param userAssignedIdentityResourceGroupName string
param userAssignedIdentityName string

/// logAnalyticsWorkspaceParameters
param logAnalyticsWorkspaceResourceGroupName string = ''
param logAnalyticsWorkspaceName string = ''

/// tags
param tags object = {}

/// resources
resource containerRegistry_resource 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: toLower(containerRegistryName)
  location: location
  tags: tags
  sku: {
    name: networkIsolation ? 'Premium' : containerRegistrySku
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceId(userAssignedIdentityResourceGroupName, 'Microsoft.ManagedIdentity/userAssignedIdentities', userAssignedIdentityName)}': {}
    }
  }
  properties: networkIsolation ? containerRegistryPremiumProperties : containerRegistryStandardProperties
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: toLower(replace(resourceGroup().name, '-rg', '-ds-azcli'))
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
    azCliVersion: '2.60.0'
    environmentVariables: [
      {
        name: 'containerRegistryName'
        value: toLower(containerRegistryName)
      }
      {
        name: 'applicationName'
        value: applicationName
      }
      {
        name: 'applicationImageToImport'
        value: applicationImageToImport
      }
      {
        name: 'containerRegistrySku'
        value: containerRegistrySku
      }
      {
        name: 'DockerHubUserName'
        value: DockerHubUserName
      }
      {
        name: 'DockerHubToken'
        value: DockerHubToken
      }
    ]
    scriptContent: '''
      decodeOption=$(echo | base64 -d 2>&1 > /dev/null && echo '-d' || echo '-D')

      # Function to check if the image tag exists in the registry
      imageTagExists() {
        registryName=$1
        repositoryName=$2
        tag=$3
        exists=$(az acr repository show-tags --name "$registryName" --repository "$repositoryName" --query "contains([*], '$tag')" --output tsv)
        echo "$exists"
      }

      # Check if the image tag already exists
      tagExists=$(imageTagExists "$containerRegistryName" "$applicationName" "latest")

      if [ "$tagExists" = "true" ]; then
        echo "Tag $applicationName:latest already exists in $containerRegistryName. Skipping import."
      else
        if [ "$containerRegistrySku" = "premium" ]; then
          az acr update --name $containerRegistryName --public-network-enabled true
          az acr import --name $containerRegistryName --source $applicationImageToImport --image $applicationName:latest --username $(echo $DockerHubUserName | base64 $decodeOption) --password $(echo $DockerHubToken | base64 $decodeOption)
          az acr artifact-streaming update --name $containerRegistryName --repository $applicationName --enable-streaming true
          az acr update --name $containerRegistryName --public-network-enabled false
        else
          az acr import --name $containerRegistryName --source $applicationImageToImport --image $applicationName:latest --username $(echo $DockerHubUserName | base64 $decodeOption) --password $(echo $DockerHubToken | base64 $decodeOption)
        fi
      fi
    '''
    timeout: 'PT1H'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
  }
  dependsOn: [
    containerRegistry_resource
    containerRegistryContributor_roleAssignment_resource
    containerRegistryACRRepositoryContributor_roleAssignment_resource
  ]
}

resource managedIdentity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(userAssignedIdentityResourceGroupName)
  name: userAssignedIdentityName
}

var containerRegistryACRRepositoryContributor = '2efddaa5-3f1f-4df3-97df-af3f13818f4c'

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

var containerRegistryContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource containerRegistryContributor_roleDefinition_resource 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: containerRegistryContributor
  scope: subscription()
}

resource containerRegistryContributor_roleAssignment_resource 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry_resource
  name: guid(containerRegistryContributor_roleDefinition_resource.name, containerRegistry_resource.name)
  properties: {
    principalType: 'ServicePrincipal'
    principalId: managedIdentity_resource.properties.principalId
    roleDefinitionId: containerRegistryContributor_roleDefinition_resource.id
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

resource registryPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = if (networkIsolation) {
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
