/*
.Synopsis
    Bicep template for Container Apps.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.App/managedEnvironments?tabs=bicep#template-format
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.App/containerapps?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240805
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// parameters
param location string

param containerAppsManagedEnvironmentName string
param containerAppsName string
param containerAppsImage string
param containerAppsPort int
param containerAppsFolders array

/// virtualNetworkParameters
param virtualNetworkResourceGroupName string
param virtualNetworkName string
param virtualNetworkSubnetName string

/// containerRegistryParameters
param containerRegistryResourceGroupName string
param containerRegistryName string

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

resource containerRegistry_resource 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  scope: resourceGroup(containerRegistryResourceGroupName)
  name: toLower(containerRegistryName)
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
  resource storage_share01 'storages' = {
    name: '${storageAccount_resource.name}-${containerAppsFolders[0]}'
    properties: {
      azureFile: {
        accountName: storageAccount_resource.name
        accountKey: storageAccount_resource.listKeys().keys[0].value
        shareName: containerAppsFolders[0]
        accessMode: 'ReadWrite'
      }
    }
  }
  resource storage_share_02 'storages' = {
    name: '${storageAccount_resource.name}-${containerAppsFolders[1]}'
    properties: {
      azureFile: {
        accountName: storageAccount_resource.name
        accountKey: storageAccount_resource.listKeys().keys[0].value
        shareName: containerAppsFolders[1]
        accessMode: 'ReadWrite'
      }
    }
  }
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
      registries: [
        {
          identity: managedIdentity_resource.id
          server: containerRegistry_resource.properties.loginServer
        }
      ]
    }
    environmentId: managedEnvironment_resource.id
    template: {
      containers: [
        {
          name: toLower(containerAppsName)
          image: toLower('${containerRegistry_resource.properties.loginServer}/${containerAppsImage}')
          resources: {
            #disable-next-line BCP036
            cpu: '1.0'
            memory: '2.0Gi'
          }
          volumeMounts: [
            {
              volumeName: containerAppsFolders[0]
              mountPath: '/${containerAppsFolders[0]}'
            }

            {
              volumeName: containerAppsFolders[1]
              mountPath: '/${containerAppsFolders[1]}'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
      volumes: [
        {
          name: containerAppsFolders[0]
          storageName: '${storageAccount_resource.name}-${containerAppsFolders[0]}'
          storageType: 'AzureFile'
        }
        {
          name: containerAppsFolders[1]
          storageName: '${storageAccount_resource.name}-${containerAppsFolders[1]}'
          storageType: 'AzureFile'
        }
      ]
    }
  }
}
