/*
.Synopsis
    Terraform template for Container Apps.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240817
*/

/// resource
data "azurerm_virtual_network" "this_resource" {
  name                = var.virtualNetworkName
  resource_group_name = var.virtualNetworkResourceGroupName
}

data "azurerm_subnet" "this_resource" {
  name                 = var.virtualNetworkSubnetName
  resource_group_name  = var.virtualNetworkResourceGroupName
  virtual_network_name = data.azurerm_virtual_network.this_resource.name
}

data "azurerm_user_assigned_identity" "this_resource" {
  name                = var.userAssignedIdentityName
  resource_group_name = var.userAssignedIdentityResourceGroupName
}

data "azurerm_log_analytics_workspace" "this_resource" {
  count               = length(var.logAnalyticsWorkspaceName) > 0 && length(var.logAnalyticsWorkspaceResourceGroupName) > 0 ? 1 : 0
  name                = var.logAnalyticsWorkspaceName
  resource_group_name = var.logAnalyticsWorkspaceResourceGroupName
}

data "azurerm_storage_account" "this_resource" {
  name                = var.storageAccountName
  resource_group_name = var.storageAccountResourceGroupName
}

resource "azurerm_container_app_environment" "this_resource" {
  name                       = var.containerAppsManagedEnvironmentName
  location                   = var.deploymentLocation
  resource_group_name        = var.deploymentResourceGroupName
  infrastructure_subnet_id   = data.azurerm_subnet.this_resource.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this_resource[0].id
  lifecycle {
    ignore_changes = [
      infrastructure_subnet_id,
      log_analytics_workspace_id
    ]
  }
}

resource "azurerm_container_app_environment_storage" "this_resource_share" {
  for_each                     = var.containerAppsFolder
  name                         = "${var.storageAccountName}-${each.value}"
  container_app_environment_id = azurerm_container_app_environment.this_resource.id
  account_name                 = var.storageAccountName
  share_name                   = each.value
  access_key                   = data.azurerm_storage_account.this_resource.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "this_resource" {
  name                = var.containerAppsName
  resource_group_name = var.deploymentResourceGroupName
  revision_mode       = "Single"
  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.this_resource.id
    ]
  }
  ingress {
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
    target_port = var.containerAppsPort
  }
  container_app_environment_id = azurerm_container_app_environment.this_resource.id

  template {
    container {
      name   = var.containerAppsName
      image  = "${var.containerRegistry}/${var.containerAppsImage}"
      cpu    = var.cpuCore
      memory = "${var.memorySize}Gi"

      dynamic "volume_mounts" {
        for_each = azurerm_container_app_environment_storage.this_resource_share
        content {
          name = volume_mounts.value.share_name
          path = "/${volume_mounts.value.share_name}"
        }
      }
    }
    min_replicas = 1
    max_replicas = 3

    dynamic "volume" {
      for_each = azurerm_container_app_environment_storage.this_resource_share
      content {
        name         = volume.value.share_name
        storage_name = volume.value.name
        storage_type = "AzureFile"
      }
    }
  }
}
