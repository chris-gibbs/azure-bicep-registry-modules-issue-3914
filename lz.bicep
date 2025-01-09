// Main template to deploy a set of landing zone components at a subscription level
targetScope = 'subscription'

// Params passed at pipeline execution
@description('Deploy Synapse')
param deploySynapse bool = true

// Default params (typically added to every module)
@description('Location of resources.')
param location string = 'australiaeast'
@description('Shortname of location. Used for resource naming.')
param locationShortName string = 'syd'

@description('Shortname of organisation. Used for resource naming.')
param orgShortName string = 'org1'

@description('Shortname of Landing Zone. Used for resource naming.')
param lzShortName string = 'syn'

@description('Environment: d=dev')
@allowed([
  'd'
])
param env string = 'd'

@description('Object containing resource tags.')
param tags object = {}

@description('Enable a Can Not Delete Resource Lock.  Useful for production workloads.')
param enableResourceLock bool = false

// Other parameters

@description('Role Assignment applied to a Keyvault resource. Recommend limited use. Instead use Role Assignments to a specifc secret / key')
param kvRoleAssignments array = []

@description('Name of the KV instance')
param keyVaultName string = '${orgShortName}-kv-${lzShortName}-${env}-${locationShortName}-01'

@description('Enables/Disables the Firewalls on relevant PaaS services')
param enableFirewall bool = false

@description('Optional. Pass json array of CIDR ranges allowed on Key Vault')
param ipWhitelist array = []

@description('Optional. Pass array of CIDR ranges allowed on Key Vault and it will be automatically formatted.')
param ipWhitelistUnformatted array = []

var defaultNetworkAction = enableFirewall ? 'Deny' : 'Allow'

var ipWhitelistFormatted = [for prefix in ipWhitelistUnformatted: { value: prefix }]

var ipWhitelistVar = !empty(ipWhitelistFormatted) ? ipWhitelistFormatted : ipWhitelist

@description('Services resource group for KV and Logging Resources')
var rgServicesName = '${orgShortName}-rg-${lzShortName}-svc-${env}-${locationShortName}-01'

var userManagedIdentityName = '${orgShortName}-id-${lzShortName}-${env}-${locationShortName}-01'

// Resource Groups for Spoke VNET and Services
resource rg_services 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgServicesName
  tags: tags
  location: location
}

module keyVault 'br/public:avm/res/key-vault/vault:0.11.1' = {
  name: 'keyVaultDeploy'
  scope: rg_services
  params: {
    name: keyVaultName
    location: location
    enableRbacAuthorization: true
    enableVaultForDeployment: true
    enableVaultForDiskEncryption: true
    enablePurgeProtection: true

    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: defaultNetworkAction
      ipRules: ipWhitelistVar
    }
    enableSoftDelete: true
    publicNetworkAccess: 'Enabled'
    tags: tags
    roleAssignments: kvRoleAssignments
  }
}

module synapse 'synapse.bicep' = if (deploySynapse) {
  name: 'synapseDeploy'
  scope: subscription()
  params: {
    env: env
    kvName: keyVault.outputs.name
    location: location
    locationShortName: locationShortName
    userManagedIdentityName: userManagedIdentityName
    lzShortName: lzShortName
    orgShortName: orgShortName
    rgServicesName: rg_services.name
    tags: tags
    resourceLockType: enableResourceLock ? 'CanNotDelete' : 'None'
  }
}
