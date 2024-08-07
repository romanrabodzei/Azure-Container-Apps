/*
.Synopsis
    Terraform template for Container Registry.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240805
*/

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
  network_rule_set              = var.networkIsolation ? local.premiumNetworkRuleSet : []
  public_network_access_enabled = var.networkIsolation ? false : true
  admin_enabled                 = true
  tags                          = var.tags
  depends_on                    = [data.azurerm_user_assigned_identity.this_resource]
}

resource "azurerm_resource_deployment_script_azure_cli" "this_resource" {
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
  environment_variable {
    name  = "DockerHubUserName"
    value = var.DockerHubUserName
  }
  environment_variable {
    name  = "DockerHubToken"
    value = var.DockerHubToken
  }
  script_content     = <<EOF
    decodeOption=$(echo | base64 -d 2>&1 > /dev/null && echo '-d' || echo '-D')

    # Function to check if the image tag exists in the registry
    imageTagExists() {
      registryName=$1
      repositoryName=$2
      tag=$3
      exists=$(az acr repository show-tags --name "$registryName" --repository "$repositoryName" --query "contains([*], '$tag')" --output tsv)
      echo "$exists"
    }

    # Check if the image tag already exists
    tagExists=$(imageTagExists "$containerRegistryName" "$applicationName" "latest")

    if [ "$tagExists" = "true" ]; then
      echo "Tag $applicationName:latest already exists in $containerRegistryName. Skipping import."
    else
      if [ "$containerRegistrySku" = "premium" ]; then
        az acr update --name $containerRegistryName --public-network-enabled true
        az acr import --name $containerRegistryName --source $applicationImageToImport --image $applicationName:latest --username $(echo $DockerHubUserName | base64 $decodeOption) --password $(echo $DockerHubToken | base64 $decodeOption)
        az acr artifact-streaming update --name $containerRegistryName --repository $applicationName --enable-streaming true
        az acr update --name $containerRegistryName --public-network-enabled false
      else
        az acr import --name $containerRegistryName --source $applicationImageToImport --image $applicationName:latest --username $(echo $DockerHubUserName | base64 $decodeOption) --password $(echo $DockerHubToken | base64 $decodeOption)
      fi
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

resource "azurerm_role_assignment" "acr_repository_contributor" {
  scope                = azurerm_container_registry.this_resource.id
  role_definition_name = "ACR Repository Contributor"
  principal_type       = "ServicePrincipal"
  principal_id         = data.azurerm_user_assigned_identity.this_resource.principal_id
}

resource "azurerm_role_assignment" "container_registry_contributor" {
  scope                = azurerm_container_registry.this_resource.id
  role_definition_name = "Contributor"
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
  enabled_log {
    category_group = "allLogs"
  }
  metric {
    category = "AllMetrics"
  }
}

/// outputs
output "container_registry_id" {
  value = azurerm_container_registry.this_resource.id
}
