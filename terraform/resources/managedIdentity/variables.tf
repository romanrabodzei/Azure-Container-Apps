/*
.Synopsis
    Terraform template for User-Assigned Identities.
    Template:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240805
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

variable "userAssignedIdentityName" {
  type        = string
  description = "The name of the user-assigned identity."
}

/// tags
variable "tags" {
  type    = map(string)
  default = {}
}