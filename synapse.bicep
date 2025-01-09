targetScope = 'subscription'

// Params passed at pipeline execution
@description('Activate CMK for Synapse Workspace')
param encryptionActivateWorkspace bool = true

// Params file or default values
@description('Location of resources.')
param location string
@description('Shortname of location. Used for resource naming.')
param locationShortName string

@description('Shortname of organisation. Used for resource naming.')
param orgShortName string

@description('Shortname of Landing Zone. Used for resource naming.')
param lzShortName string

@description('Object containing resource tags.')
param tags object = {}

@allowed([
  'None'
  'CanNotDelete'
  'ReadOnly'
])
@description('Optional. Specify the type of lock.')
param resourceLockType string = 'None'

@description('Environment: d=dev')
@allowed([
  'd'
])
param env string

@description('Keyvault Name')
param kvName string

@description('Services Resource Group Name')
param rgServicesName string

@description('User-assigned Managed Identity Name')
param userManagedIdentityName string

@description('Data Lake Storage Filesystem Name')
param defaultDataLakeStorageFilesystem string = 'adlsdata'

@description('Synapse SQL Administrator Login')
param sqlAdministratorLogin string = 'synapseSQLAdmin'

var rgSynapseName = '${orgShortName}-rg-${lzShortName}-syn-${env}-${locationShortName}-01'
var synapseWorkspaceName = '${orgShortName}-swor-${lzShortName}-${env}-${locationShortName}-01'

var storageAccountName = '${orgShortName}${lzShortName}${env}${locationShortName}01'

resource rgServices 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: rgServicesName
}

resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: kvName
  scope: rgServices
}

resource rgSynapse 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgSynapseName
  tags: tags
  location: location
}

module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'userAssignedIdentityDeploy'
  scope: resourceGroup(rgSynapse.name)
  params: {
    name: userManagedIdentityName
    location: location
    lock: {
      kind: resourceLockType
    }
    tags: tags
    roleAssignments: []
  }
}

module synapseCMK './key.bicep' = {
  name: 'synapseCMKDeploy'
  scope: resourceGroup(rgServices.name)
  params: {
    keyVaultName: kvName
    name: '${synapseWorkspaceName}-cmk'
    keySize: 2048
    kty: 'RSA'
    attributesEnabled: true
    tags: tags
    roleAssignments: [
      {
        principalIds: [userAssignedIdentity.outputs.principalId]
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Crypto Officer'
      }
      {
        principalIds: [userAssignedIdentity.outputs.principalId]
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
      }
    ]
  }
}

module synapseStorage 'br/public:avm/res/storage/storage-account:0.14.1' = {
  name: 'synapseStorageDeploy'
  scope: resourceGroup(rgSynapse.name)
  params: {
    name: storageAccountName
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    allowSharedKeyAccess: true
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
    requireInfrastructureEncryption: true
    enableHierarchicalNamespace: true
    customerManagedKey: {
      keyName: synapseCMK.outputs.name
      keyVaultResourceId: kv.id
      userAssignedIdentityResourceId: userAssignedIdentity.outputs.resourceId
    }
    managedIdentities: {
      systemAssigned: false
      userAssignedResourceIds: [
        userAssignedIdentity.outputs.resourceId
      ]
    }
    roleAssignments: [
      {
        principalId: userAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
    ]
    lock: { kind: resourceLockType }
    tags: tags
    fileServices: {}
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 9
      deleteRetentionPolicyEnabled: true
    }
    queueServices: {}
    tableServices: {}
    privateEndpoints: []
  }
}
module synapseWorkspace 'br/public:avm/res/synapse/workspace:0.9.1' = {
  scope: rgSynapse
  name: 'synapseWorkspaceDeploy'
  params: {
    name: synapseWorkspaceName
    lock: {
      kind: resourceLockType
    }
    tags: tags
    diagnosticSettings: []
    defaultDataLakeStorageAccountResourceId: synapseStorage.outputs.resourceId
    defaultDataLakeStorageFilesystem: defaultDataLakeStorageFilesystem
    defaultDataLakeStorageCreateManagedPrivateEndpoint: true
    azureADOnlyAuthentication: false
    managedIdentities: {
      userAssignedResourceIds: [
        userAssignedIdentity.outputs.resourceId
      ]
    }
    managedResourceGroupName: '${rgSynapseName}-managed'
    managedVirtualNetwork: true
    publicNetworkAccess: 'Enabled'
    allowedAadTenantIdsForLinking: [subscription().tenantId]
    encryptionActivateWorkspace: encryptionActivateWorkspace
    customerManagedKey: {
      keyName: '${synapseWorkspaceName}-cmk'
      keyVaultResourceId: kv.id
    }
    sqlAdministratorLogin: sqlAdministratorLogin
  }
}
