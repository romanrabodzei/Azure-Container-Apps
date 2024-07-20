/*
.Synopsis
    Terraform template for Container Apps.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240719
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

variable "containerAppsManagedEnvironmentName" {
  type        = string
  description = "The name of the managed environment."
}

variable "containerAppsName" {
  type        = string
  description = "The name of the container app."
}

variable "containerAppsImage" {
  type        = string
  description = "The image of the container app."
}

variable "containerAppsPort" {
  type        = number
  description = "The ports of the container app."
}

variable "containerAppsFolder" {
  type        = string
  description = "The folder of the container app."
}

variable "virtualNetworkResourceGroupName" {
  type        = string
  description = "The resource group name of the virtual network."
}

variable "virtualNetworkName" {
  type        = string
  description = "The name of the virtual network."
}

variable "virtualNetworkSubnetName" {
  type        = string
  description = "The name of the subnet."
}

variable "containerRegistryResourceGroupName" {
  type        = string
  description = "The resource group name of the container registry."
}

variable "containerRegistryName" {
  type        = string
  description = "The name of the container registry."
}

variable "storageAccountResourceGroupName" {
  type        = string
  description = "The resource group name of the storage account."
}

variable "storageAccountName" {
  type        = string
  description = "The name of the storage account."
}

variable "userAssignedIdentityResourceGroupName" {
  type        = string
  description = "The resource group name of the user assigned identity."
}

variable "userAssignedIdentityName" {
  type        = string
  description = "The name of the user assigned identity."
}

variable "logAnalyticsWorkspaceResourceGroupName" {
  type        = string
  description = "The resource group name of the log analytics workspace."
}

variable "logAnalyticsWorkspaceName" {
  type        = string
  description = "The name of the log analytics workspace."
}

/// tags
variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource."
  default     = {}
}

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

data "azurerm_container_registry" "this_resource" {
  name                = var.containerRegistryName
  resource_group_name = var.deploymentResourceGroupName
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

resource "azurerm_container_app_environment_storage" "this_resource" {
  name                         = var.storageAccountName
  container_app_environment_id = azurerm_container_app_environment.this_resource.id
  account_name                 = var.storageAccountName
  share_name                   = "fileshare"
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
    target_port  = var.containerAppsPort
  }
  registry {
    identity = data.azurerm_user_assigned_identity.this_resource.id
    server   = data.azurerm_container_registry.this_resource.login_server
  }
  container_app_environment_id = azurerm_container_app_environment.this_resource.id

  template {
    container {
      name   = var.containerAppsName
      image  = "${data.azurerm_container_registry.this_resource.login_server}/${var.containerAppsImage}"
      cpu    = 0.25
      memory = "0.5Gi"
      volume_mounts {
        name = var.containerAppsFolder
        path = var.containerAppsFolder
      }
    }
    min_replicas = 1
    max_replicas = 3
    volume {
      name         = var.containerAppsFolder
      storage_name = data.azurerm_storage_account.this_resource.name
      storage_type = "AzureFile"
    }
  }
}
