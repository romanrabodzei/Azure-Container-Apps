/*
.Synopsis
    Bicep template for Virtual Network.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/virtualNetworks?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240817
*/

/// deployment scope
targetScope = 'resourceGroup'

/// parameters
param location string

param virtualNetworkName string
param virtualNetworkAddressPrefix string
param virtualSubnetNames array
param virtualNetworkSubnetAddressPrefixes array
param networkSecurityGroupNames array

/// logAnalyticsWorkspaceParameters
param logAnalyticsWorkspaceName string = ''
param logAnalyticsWorkspaceResourceGroupName string = ''

/// tags
param tags object = {}

/// resources
resource virtualNetwork_resource 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
  }
  @batchSize(1)
  resource subnet 'subnets' = [
    for (virtualSubnetName, i) in virtualSubnetNames: {
      name: toLower(virtualSubnetName)
      properties: {
        addressPrefix: virtualNetworkSubnetAddressPrefixes[i]
        networkSecurityGroup: {
          id: resourceId('Microsoft.Network/networkSecurityGroups', toLower(networkSecurityGroupNames[i]))
        }
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
            locations: [
              '*'
            ]
          }
        ]
      }
    }
  ]
}

var networkSecurityGroups = [
  'containerApps'
  // 'privateEndpoints'
]

var securityRules = {
  containerApps: [
    {
      name: 'AllowAnyHTTPSInbound'
      properties: {
        protocol: 'TCP'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 100
        direction: 'Inbound'
        sourcePortRanges: []
        destinationPortRanges: []
        sourceAddressPrefixes: []
        destinationAddressPrefixes: []
      }
    }
  ]
  // privateEndpoints: []
}

resource networkSecurityGroup_resource 'Microsoft.Network/networkSecurityGroups@2023-11-01' = [
  for (networkSecurityGroup, i) in networkSecurityGroups: {
    name: toLower(networkSecurityGroupNames[i])
    location: location
    tags: tags
    properties: {
      securityRules: securityRules[networkSecurityGroup]
    }
  }
]

resource logAnalytics_resource 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = if (!empty(logAnalyticsWorkspaceName) && !empty(logAnalyticsWorkspaceResourceGroupName)) {
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
  name: logAnalyticsWorkspaceName
}

resource send_data_to_logAnalyticsWorkspace_virtualNetwork 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceName) && !empty(logAnalyticsWorkspaceResourceGroupName)) {
  scope: virtualNetwork_resource
  name: toLower('send-data-to-${logAnalyticsWorkspaceName}')
  properties: {
    workspaceId: logAnalytics_resource.id
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource send_data_to_logAnalyticsWorkspace_networkSecurityGroup 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [
  for (networkSecurityGroup, i) in networkSecurityGroups: if (!empty(logAnalyticsWorkspaceName) && !empty(logAnalyticsWorkspaceResourceGroupName)) {
    scope: networkSecurityGroup_resource[i]
    name: toLower('send-data-to-${logAnalyticsWorkspaceName}')
    properties: {
      workspaceId: logAnalytics_resource.id
      logs: [
        {
          category: 'NetworkSecurityGroupEvent'
          enabled: true
        }
        {
          category: 'NetworkSecurityGroupRuleCounter'
          enabled: true
        }
      ]
      metrics: []
    }
  }
]

/// output
output virtualNetworkId string = virtualNetwork_resource.id
