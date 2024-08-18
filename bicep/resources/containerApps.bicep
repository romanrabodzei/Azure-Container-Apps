/*
.Synopsis
    Bicep template for Container Apps.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.App/managedEnvironments?tabs=bicep#template-format
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.App/containerapps?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240817
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// parameters
param location string

param containerAppsManagedEnvironmentName string
param containerAppsName string
param containerAppsImage string
param containerAppsPort int
param containerRegistry string
param containerAppsFolders array

@description('Number of CPU cores the container can use. Can be with a maximum of two decimals.')
@allowed(['0.25', '0.5', '0.75', '1.0', '1.25', '1.5', '1.75', '2.0'])
param cpuCore string = '1.0'

@description('Amount of memory (in gibibytes, GiB) allocated to the container up to 4GiB. Can be with a maximum of two decimals. Ratio with CPU cores must be equal to 2.')
@allowed(['0.5', '1.0', '1.5', '2.0', '3.0', '3.5', '4.0'])
param memorySize string = '2.0'

/// virtualNetworkParameters
param virtualNetworkResourceGroupName string
param virtualNetworkName string
param virtualNetworkSubnetName string

/// storageAccountParameters
param storageAccountResourceGroupName string
param storageAccountName string

/// managedIdentityParameters
param userAssignedIdentityResourceGroupName string
param userAssignedIdentityName string

/// logAnalyticsWorkspaceParameters
param logAnalyticsWorkspaceResourceGroupName string = ''
param logAnalyticsWorkspaceName string = ''

/// tags
param tags object = {}

/// resources
resource virtualNetwork_resource 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
  resource subnet 'subnets' existing = {
    name: virtualNetworkSubnetName
  }
}

resource managedIdentity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(userAssignedIdentityResourceGroupName)
  name: userAssignedIdentityName
}

resource logAnalytics_workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
  name: logAnalyticsWorkspaceName
}

resource storageAccount_resource 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  scope: resourceGroup(storageAccountResourceGroupName)
  name: storageAccountName
}

resource managedEnvironment_resource 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: toLower(containerAppsManagedEnvironmentName)
  location: location
  tags: tags
  #disable-next-line BCP187
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity_resource.id}': {}
    }
  }
  properties: {
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: virtualNetwork_resource::subnet.id
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics_workspace.properties.customerId
        sharedKey: logAnalytics_workspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
    kedaConfiguration: {}
    daprConfiguration: {}
    customDomainConfiguration: {}
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
  }
  resource storage_share 'storages' = [
    for (list, item) in containerAppsFolders: {
      name: '${storageAccount_resource.name}-${containerAppsFolders[item]}'
      properties: {
        azureFile: {
          accountName: storageAccount_resource.name
          accountKey: storageAccount_resource.listKeys().keys[0].value
          shareName: containerAppsFolders[item]
          accessMode: 'ReadWrite'
        }
      }
    }
  ]
}

resource containerApps_resource 'Microsoft.App/containerApps@2024-03-01' = {
  name: toLower(containerAppsName)
  location: location
  #disable-next-line BCP187
  kind: 'containerapps'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity_resource.id}': {}
    }
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        additionalPortMappings: []
        allowInsecure: false
        clientCertificateMode: 'ignore'
        external: true
        stickySessions: {
          affinity: 'none'
        }
        targetPort: containerAppsPort
        transport: 'Auto'
      }
    }
    environmentId: managedEnvironment_resource.id
    template: {
      containers: [
        {
          name: toLower(containerAppsName)
          image: toLower('${containerRegistry}/${containerAppsImage}')
          resources: {
            #disable-next-line BCP036
            cpu: cpuCore
            memory: '${memorySize}Gi'
          }
          volumeMounts: [
            for (list, item) in containerAppsFolders: {
              volumeName: containerAppsFolders[item]
              mountPath: '/${containerAppsFolders[item]}'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
      volumes: [
        for (list, item) in containerAppsFolders: {
          name: containerAppsFolders[item]
          storageName: '${storageAccount_resource.name}-${containerAppsFolders[item]}'
          storageType: 'AzureFile'
        }
      ]
    }
  }
}
