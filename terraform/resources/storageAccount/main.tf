/*
.Synopsis
    Terraform template for Standard Storage Account.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240805
*/

/// resources
resource "azurerm_storage_account" "this_resource" {
  name                          = lower(var.storageAccountName)
  location                      = var.deploymentLocation
  resource_group_name           = var.deploymentResourceGroupName
  account_replication_type      = var.storageAccountType
  account_kind                  = var.storageAccountKind
  account_tier                  = "Standard"
  min_tls_version               = "TLS1_2"
  enable_https_traffic_only     = true
  shared_access_key_enabled     = true
  public_network_access_enabled = var.networkIsolation ? false : true
  network_rules {
    bypass         = ["AzureServices"]
    default_action = var.networkIsolation ? "Deny" : "Allow"
  }
  tags = var.tags
}

resource "azurerm_storage_share" "this_resource" {
  for_each             = toset(var.storageAccountFileShareName)
  name                 = each.value
  storage_account_name = azurerm_storage_account.this_resource.name
  access_tier          = "Hot"
  enabled_protocol     = "SMB"
  quota                = 1024
}

data "azurerm_user_assigned_identity" "this_resource" {
  name                = var.userAssignedIdentityName
  resource_group_name = var.userAssignedIdentityResourceGroupName
}

resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = azurerm_storage_account.this_resource.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_type       = "ServicePrincipal"
  principal_id         = data.azurerm_user_assigned_identity.this_resource.principal_id
}


resource "azurerm_role_assignment" "file_data_contributor" {
  scope                = azurerm_storage_account.this_resource.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_type       = "ServicePrincipal"
  principal_id         = data.azurerm_user_assigned_identity.this_resource.principal_id
}

data "azurerm_virtual_network" "this_resource" {
  name                = var.virtualNetworkName
  resource_group_name = var.virtualNetworkResourceGroupName
}

data "azurerm_subnet" "this_resource" {
  name                 = var.virtualNetworkSubnetName
  resource_group_name  = var.virtualNetworkResourceGroupName
  virtual_network_name = data.azurerm_virtual_network.this_resource.name
}

resource "azurerm_dns_zone" "file_private_connection" {
  count               = var.networkIsolation ? 1 : 0
  name                = replace(local.fileSharePrivateDnsZoneName, "_", ".")
  resource_group_name = var.deploymentResourceGroupName
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "file_private_connection" {
  count                 = var.networkIsolation ? 1 : 0
  name                  = replace(local.fileSharePrivateDnsZoneName, "_", "-")
  resource_group_name   = var.deploymentResourceGroupName
  private_dns_zone_name = azurerm_dns_zone.file_private_connection[0].name
  virtual_network_id    = data.azurerm_virtual_network.this_resource.id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "this_resource" {
  count               = var.networkIsolation ? 1 : 0
  name                = lower("${var.storageAccountName}-file-pe")
  location            = var.deploymentLocation
  resource_group_name = var.deploymentResourceGroupName
  subnet_id           = data.azurerm_subnet.this_resource.id
  private_service_connection {
    name                           = lower("${var.storageAccountName}-file-pe-nic")
    private_connection_resource_id = azurerm_storage_account.this_resource.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = replace(local.fileSharePrivateDnsZoneName, "_", ".")
    private_dns_zone_ids = [azurerm_dns_zone.file_private_connection[0].id]
  }
}

resource "azurerm_dns_zone" "queue_private_connection" {
  count               = var.networkIsolation ? 1 : 0
  name                = replace(local.queuePrivateDnsZoneName, "_", ".")
  resource_group_name = var.deploymentResourceGroupName
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "queue_private_connection" {
  count                 = var.networkIsolation ? 1 : 0
  name                  = replace(local.queuePrivateDnsZoneName, "_", "-")
  resource_group_name   = var.deploymentResourceGroupName
  private_dns_zone_name = azurerm_dns_zone.queue_private_connection[0].name
  virtual_network_id    = data.azurerm_virtual_network.this_resource.id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "queue_private_connection" {
  count               = var.networkIsolation ? 1 : 0
  name                = lower("${var.storageAccountName}-queue-pe")
  location            = var.deploymentLocation
  resource_group_name = var.deploymentResourceGroupName
  subnet_id           = data.azurerm_subnet.this_resource.id
  private_service_connection {
    name                           = lower("${var.storageAccountName}-queue-pe-nic")
    private_connection_resource_id = azurerm_storage_account.this_resource.id
    subresource_names              = ["queue"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = replace(local.queuePrivateDnsZoneName, "_", ".")
    private_dns_zone_ids = [azurerm_dns_zone.queue_private_connection[0].id]
  }
}

data "azurerm_log_analytics_workspace" "this_resource" {
  count               = length(var.logAnalyticsWorkspaceName) > 0 && length(var.logAnalyticsWorkspaceResourceGroupName) > 0 ? 1 : 0
  name                = var.logAnalyticsWorkspaceName
  resource_group_name = var.logAnalyticsWorkspaceResourceGroupName
}

resource "azurerm_monitor_diagnostic_setting" "nthis_resourceame" {
  name                       = lower("send-data-to-${var.logAnalyticsWorkspaceName}")
  target_resource_id         = azurerm_storage_account.this_resource.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this_resource[0].id
  metric {
    category = "Capacity"
  }
  metric {
    category = "Transaction"
  }
}

/// outputs
output "storage_account_id" {
  value = azurerm_storage_account.this_resource.id
}
