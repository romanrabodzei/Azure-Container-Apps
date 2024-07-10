/*
.Synopsis
    Terraform template for Log Analytics Workspace.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.OperationalInsights/workspaces?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240704
*/

/// variables
variable "deploymentResourceGroupName" {
  type        = string
  description = "Deployment resource group name."
}

variable "deploymentLocation" {
  type        = string
  description = "The location where the resources will be deployed."
}

variable "logAnalyticsWorkspaceName" {
  type        = string
  description = "The name of the Log Analytics Workspace."
}

variable "logAnalyticsWorkspaceSku" {
  type    = string
  default = "PerGB2018"
}

variable "logAnalyticsWorkspaceRetentionInDays" {
  type    = number
  default = 30
}

variable "logAnalyticsWorkspaceDailyQuotaGb" {
  type    = number
  default = -1
}

variable "logAnalyticsWorkspacePublicNetworkAccess" {
  type    = bool
  default = true
  validation {
    condition     = var.logAnalyticsWorkspacePublicNetworkAccess == true || var.logAnalyticsWorkspacePublicNetworkAccess == false
    error_message = "The value must be 'true' or 'false'."
  }
}

// tags
variable "tags" {
  type    = map(string)
  default = {}
}

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