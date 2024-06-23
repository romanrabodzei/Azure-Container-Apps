/*
.Synopsis
    Bicep template for Log Analytics Workspace.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.OperationalInsights/workspaces?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240622
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// parameters
param location string

param logAnalyticsWorkspaceName string
param logAnalyticsWorkspaceSku string = 'pergb2018'
param logAnalyticsWorkspaceRetentionInDays int = 30
param logAnalyticsWorkspaceDailyQuotaGb int = -1
@allowed([
  'Enabled'
  'Disabled'
])
param logAnalyticsWorkspacePublicNetworkAccess string = 'Enabled'

/// tags
param tags object = {}

/// resources
resource logAnalyticsWorkspace_resource 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: toLower(logAnalyticsWorkspaceName)
  location: location
  tags: tags
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSku
    }
    retentionInDays: logAnalyticsWorkspaceRetentionInDays
    publicNetworkAccessForIngestion: logAnalyticsWorkspacePublicNetworkAccess
    publicNetworkAccessForQuery: logAnalyticsWorkspacePublicNetworkAccess
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsWorkspaceDailyQuotaGb
    }
  }
}

/// output
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace_resource.id
