/*
.Synopsis
    Terraform template for Log Analytics Workspace.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.OperationalInsights/workspaces?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240805
*/

/// resources
resource "azurerm_log_analytics_workspace" "this_resource" {
  name                       = lower(var.logAnalyticsWorkspaceName)
  location                   = var.deploymentLocation
  resource_group_name        = var.deploymentResourceGroupName
  tags                       = var.tags
  sku                        = var.logAnalyticsWorkspaceSku
  retention_in_days          = var.logAnalyticsWorkspaceRetentionInDays
  internet_ingestion_enabled = var.logAnalyticsWorkspacePublicNetworkAccess
  internet_query_enabled     = var.logAnalyticsWorkspacePublicNetworkAccess
  daily_quota_gb             = var.logAnalyticsWorkspaceDailyQuotaGb
}