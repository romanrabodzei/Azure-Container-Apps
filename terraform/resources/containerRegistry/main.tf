/*
.Synopsis
    Bicep template for Container Registry.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240708
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

variable "containerRegistryName" {
  type        = string
  description = "The name of the container registry."
}

variable "containerRegistrySku" {
  type        = string
  description = "The SKU of the container registry."
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.containerRegistrySku)
    error_message = "The container registry SKU must be Basic, Standard, or Premium."
  }
}

variable "applicationName" {
  type        = string
  description = "The name of the application."
}

variable "applicationImageToImport" {
  type        = string
  description = "The image to import"
}

variable "networkIsolation" {
  type        = bool
  description = "Enable network isolation."
  default     = true
}

variable "virtualNetworkResourceGroupName" {
  type        = string
  description = "The name of the resource group where the virtual network is located."
  default     = ""
}

variable "virtualNetworkName" {
  type        = string
  description = "The name of the virtual network."
  default     = ""
}

variable "virtualNetworkSubnetName" {
  type        = string
  description = "The name of the subnet."
  default     = ""
}

variable "userAssignedIdentityResourceGroupName" {
  type        = string
  description = "The name of the resource group where the user-assigned identity is located."
}

variable "userAssignedIdentityName" {
  type        = string
  description = "The name of the user-assigned identity."
}

variable "logAnalyticsWorkspaceResourceGroupName" {
  type        = string
  description = "The name of the resource group where the Log Analytics workspace is located."
  default     = ""
}

variable "logAnalyticsWorkspaceName" {
  type        = string
  description = "The name of the Log Analytics workspace."
  default     = ""
}

/// tags
variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource."
  default     = {}
}

/// locals
locals {
  registryPrivateDnsZoneName                = "privatelink_azurecr_io"
  containerRegistryACRRepositoryContributor = "2efddaa5-3f1f-4df3-97df-af3f13818f4c"
  containerRegistryContributor              = "b24988ac-6180-42a0-ab88-20f7382dd24c"
}

/// resources
resource "azurerm_container_registry" "this_resource" {
  name                = var.containerRegistryName
  resource_group_name = var.deploymentResourceGroupName
  location            = var.deploymentLocation
  sku                 = var.networkIsolation ? "Premium" : var.containerRegistrySku
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.this_resource.id]
  }
  network_rule_set = [{
    default_action  = var.networkIsolation ? "Deny" : "Allow"
    bypass          = ["AzureServices"]
    ip_rule         = []
    virtual_network = []
  }]
  public_network_access_enabled = var.networkIsolation ? false : true
  admin_enabled                 = true
  tags                          = var.tags
  depends_on                    = [data.azurerm_user_assigned_identity.this_resource]
}

resource "azurerm_resource_deployment_script_azure_cli" "example" {
  name                = replace(var.deploymentResourceGroupName, "-rg", "-ds-azcli")
  resource_group_name = var.deploymentResourceGroupName
  location            = var.deploymentLocation
  tags                = var.tags
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.this_resource.id]
  }
  version = "2.60.0"
  environment_variable {
    name  = "containerRegistryName"
    value = azurerm_container_registry.this_resource.name
  }
  environment_variable {
    name  = "applicationName"
    value = var.applicationName
  }
  environment_variable {
    name  = "applicationImageToImport"
    value = var.applicationImageToImport
  }
  environment_variable {
    name  = "containerRegistrySku"
    value = var.containerRegistrySku
  }
  script_content     = <<EOF
    if [ "$containerRegistrySku" = "premium" ]; then
      az acr update --name $containerRegistryName --public-network-enabled true
      az acr import --name $containerRegistryName --source $applicationImageToImport --image $applicationName:latest
      az acr artifact-streaming update --name $containerRegistryName --repository $applicationName --enable-streaming true
      az acr update --name $containerRegistryName --public-network-enabled false
    else
      az acr import --name $containerRegistryName --source $applicationImageToImport --image $applicationName:latest
    fi
  EOF
  timeout            = "PT1H"
  retention_interval = "PT1H"
  cleanup_preference = "Always"
  depends_on         = [azurerm_container_registry.this_resource, data.azurerm_user_assigned_identity.this_resource, azurerm_role_assignment.acr_repository_contributor, azurerm_role_assignment.container_registry_contributor]
}

data "azurerm_user_assigned_identity" "this_resource" {
  name                = var.userAssignedIdentityName
  resource_group_name = var.userAssignedIdentityResourceGroupName
}

data "azurerm_role_definition" "acr_repository_contributor" {
  name  = local.containerRegistryACRRepositoryContributor
  scope = var.deploymentResourceGroupName
}

resource "azurerm_role_assignment" "acr_repository_contributor" {
  scope              = azurerm_container_registry.this_resource.id
  name               = local.containerRegistryACRRepositoryContributor
  principal_type     = "ServicePrincipal"
  principal_id       = data.azurerm_user_assigned_identity.this_resource.principal_id
  role_definition_id = data.azurerm_role_definition.acr_repository_contributor.id
}

data "azurerm_role_definition" "container_registry_contributor" {
  name  = local.containerRegistryContributor
  scope = var.deploymentResourceGroupName
}

resource "azurerm_role_assignment" "container_registry_contributor" {
  scope              = azurerm_container_registry.this_resource.id
  name               = local.containerRegistryContributor
  principal_type     = "ServicePrincipal"
  principal_id       = data.azurerm_user_assigned_identity.this_resource.principal_id
  role_definition_id = data.azurerm_role_definition.container_registry_contributor.id
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

resource "azurerm_dns_zone" "registry_private_connection" {
  count               = var.networkIsolation ? 1 : 0
  name                = replace(local.registryPrivateDnsZoneName, "_", ".")
  resource_group_name = var.deploymentResourceGroupName
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "registry_private_connection" {
  count                 = var.networkIsolation ? 1 : 0
  name                  = replace(local.registryPrivateDnsZoneName, "_", "-")
  resource_group_name   = var.deploymentResourceGroupName
  private_dns_zone_name = azurerm_dns_zone.registry_private_connection[0].name
  virtual_network_id    = data.azurerm_virtual_network.this_resource.id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "this_resource" {
  count               = var.networkIsolation ? 1 : 0
  name                = lower("${var.containerRegistryName}-registry-pe")
  location            = var.deploymentLocation
  resource_group_name = var.deploymentResourceGroupName
  subnet_id           = data.azurerm_subnet.this_resource.id
  private_service_connection {
    name                           = lower("${var.containerRegistryName}-registry-pe-nic")
    private_connection_resource_id = azurerm_container_registry.this_resource.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = replace(local.registryPrivateDnsZoneName, "_", ".")
    private_dns_zone_ids = [azurerm_dns_zone.registry_private_connection[0].id]
  }
}

data "azurerm_log_analytics_workspace" "this_resource" {
  count               = length(var.logAnalyticsWorkspaceName) > 0 && length(var.logAnalyticsWorkspaceResourceGroupName) > 0 ? 1 : 0
  name                = var.logAnalyticsWorkspaceName
  resource_group_name = var.logAnalyticsWorkspaceResourceGroupName
}

resource "azurerm_monitor_diagnostic_setting" "nthis_resourceame" {
  name                       = lower("send-data-to-${var.logAnalyticsWorkspaceName}")
  target_resource_id         = azurerm_container_registry.this_resource.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this_resource[0].id
  metric {
    category = "Transaction"
  }
}

/// outputs
output "container_registry_id" {
  value = azurerm_container_registry.this_resource.id
}
