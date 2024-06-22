/*
.Synopsis
    Bicep template for Container Apps.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.App/managedEnvironments?tabs=bicep#template-format
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.App/containerapps?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240621
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// storageAccountParameters
param location string

param containerAppsManagedEnvironmentName string
param containerAppsName string
param containerAppsImage string
param containerAppsPort int

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
param logAnalyticsWorkspaceName string = ''
param logAnalyticsWorkspaceResourceGroupName string = ''

/// tags
param tags object = {}

/// resources
resource logAnalytics_workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
  name: logAnalyticsWorkspaceName
}

resource storageAccount_resource 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  scope: resourceGroup(storageAccountResourceGroupName)
  name: storageAccountName
}

resource managedIdentity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(userAssignedIdentityResourceGroupName)
  name: userAssignedIdentityName
}

resource virtualNetwork_resource 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
  resource subnet 'subnets' existing = {
    name: virtualNetworkSubnetName
  }
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
  resource storage 'storages' = {
    name: storageAccount_resource.name
    properties: {
      azureFile: {
        accountName: storageAccount_resource.name
        accountKey: storageAccount_resource.listKeys().keys[0].value
        shareName: 'fileshare'
        accessMode: 'ReadWrite'
      }
    }
  }
}

resource containerRegistry_resource 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  scope: resourceGroup(containerRegistryResourceGroupName)
  name: toLower(containerRegistryName)
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
            cpu: '0.25'
            memory: '.5Gi'
          }
          volumeMounts: [
            {
              mountPath: '/data'
              volumeName: 'data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'data'
          storageName: storageAccount_resource.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}
