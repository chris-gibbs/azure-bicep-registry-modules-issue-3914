// Cloned from: https://github.com/Azure/ResourceModules/blob/module-archive/modules/key-vault/vault/key/main.bicep
// renamed .bicep/nested_roleAssignments.bicep to ./key_nested_roleAssignments.bicep

metadata name = 'Key Vault Keys'
metadata description = 'This module deploys a Key Vault Key.'
metadata owner = 'Azure/module-maintainers'

@description('Conditional. The name of the parent key vault. Required if the template is used in a standalone deployment.')
param keyVaultName string

@description('Required. The name of the key.')
param name string

@description('Optional. Resource tags.')
param tags object = {}

@description('Optional. Determines whether the object is enabled.')
param attributesEnabled bool = true

@description('Optional. Expiry date in seconds since 1970-01-01T00:00:00Z. For security reasons, it is recommended to set an expiration date whenever possible.')
param attributesExp int = -1

@description('Optional. Not before date in seconds since 1970-01-01T00:00:00Z.')
param attributesNbf int = -1

@description('Optional. The elliptic curve name.')
@allowed([
  'P-256'
  'P-256K'
  'P-384'
  'P-521'
])
param curveName string = 'P-256'

@description('Optional. Array of JsonWebKeyOperation.')
@allowed([
  'decrypt'
  'encrypt'
  'import'
  'sign'
  'unwrapKey'
  'verify'
  'wrapKey'
])
param keyOps array = []

@description('Optional. The key size in bits. For example: 2048, 3072, or 4096 for RSA.')
param keySize int = -1

@description('Optional. The type of the key.')
@allowed([
  'EC'
  'EC-HSM'
  'RSA'
  'RSA-HSM'
])
param kty string = 'EC'

@description('Optional. Array of role assignment objects that contain the \'roleDefinitionIdOrName\' and \'principalId\' to define RBAC role assignments on this resource. In the roleDefinitionIdOrName attribute, you can provide either the display name of the role definition, or its fully qualified ID in the following format: \'/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11\'.')
param roleAssignments array = []

@description('Optional. Key rotation policy properties object.')
param rotationPolicy object = {}

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = true

resource defaultTelemetry 'Microsoft.Resources/deployments@2021-04-01' = if (enableDefaultTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource key 'Microsoft.KeyVault/vaults/keys@2022-07-01' = {
  name: name
  parent: keyVault
  tags: tags
  properties: {
    attributes: {
      enabled: attributesEnabled
      exp: attributesExp != -1 ? attributesExp : null
      nbf: attributesNbf != -1 ? attributesNbf : null
    }
    curveName: curveName
    keyOps: keyOps
    keySize: keySize != -1 ? keySize : null
    kty: kty
    rotationPolicy: !empty(rotationPolicy) ? rotationPolicy : null
  }
}

module key_roleAssignments 'key_nested_roleAssignments.bicep' = [
  for (roleAssignment, index) in roleAssignments: {
    name: '${deployment().name}-Rbac-${index}'
    params: {
      description: contains(roleAssignment, 'description') ? roleAssignment.description : ''
      principalIds: roleAssignment.principalIds
      principalType: contains(roleAssignment, 'principalType') ? roleAssignment.principalType : ''
      roleDefinitionIdOrName: roleAssignment.roleDefinitionIdOrName
      condition: contains(roleAssignment, 'condition') ? roleAssignment.condition : ''
      delegatedManagedIdentityResourceId: contains(roleAssignment, 'delegatedManagedIdentityResourceId')
        ? roleAssignment.delegatedManagedIdentityResourceId
        : ''
      resourceId: key.id
    }
  }
]

@description('The name of the key.')
output name string = key.name

@description('The resource ID of the key.')
output resourceId string = key.id

@description('The name of the resource group the key was created in.')
output resourceGroupName string = resourceGroup().name
