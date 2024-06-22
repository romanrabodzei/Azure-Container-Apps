/*
.Synopsis
    Bicep template for User-Assigned Identities. 
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.ManagedIdentity/userAssignedIdentities?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240621
*/

/// deploymentScope
targetScope = 'resourceGroup'

/// userAssignedIdentityParameters
param location string

param userAssignedIdentityName string
var userAssignedIdentitiesId = resourceId(
  'Microsoft.ManagedIdentity/userAssignedIdentities',
  userAssignedIdentityName
)

/// tags
param tags object = {}

/// resources
resource userAssignedIdentity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: toLower(userAssignedIdentityName)
  location: location
  tags: tags
}

/// output
output userAssignedIdentityId string = userAssignedIdentity_resource.id
output userAssignedIdentityClientId string = reference(userAssignedIdentitiesId).principalId
