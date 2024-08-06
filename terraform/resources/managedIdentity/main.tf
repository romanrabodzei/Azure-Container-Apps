/*
.Synopsis
    Terraform template for User-Assigned Identities.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240805
*/

/// resources
resource "azurerm_user_assigned_identity" "this_resource" {
  name                = lower(var.userAssignedIdentityName)
  location            = var.deploymentLocation
  resource_group_name = var.deploymentResourceGroupName
  tags                = var.tags
}

/// outputs
output "userAssignedIdentityId" {
  value = azurerm_user_assigned_identity.this_resource.id
}

output "userAssignedIdentityPrincipalId" {
  value = azurerm_user_assigned_identity.this_resource.principal_id
}
