/*
resource "azurerm_redis_cache" "azfinsim" {
  count               = local.inc-redis ? 1 : 0
  name                = format("%scache", var.prefix)
  resource_group_name = azurerm_resource_group.azfinsim.name
  location            = azurerm_resource_group.azfinsim.location
  capacity            = 1
  family              = local.env-prod ? "P" : "C"
  sku_name            = local.env-prod ? "Premium" : "Standard"
  enable_non_ssl_port = true
  minimum_tls_version = "1.2"

  redis_configuration {
  }
  tags                = local.resource_tags
}
*/
//ref: https://azure.microsoft.com/en-us/resources/templates/redis-cache/
param redisCacheName string
param location string = resourceGroup().location
param kvName string

@description('Specify the pricing tier of the new Azure Redis Cache.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param redisCacheSKU string = 'Standard'

@allowed([
  'C'
  'P'
])
param redisCacheFamily string = 'C'

@description('Specify the size of the new Azure Redis Cache instance. Valid values: for C (Basic/Standard) family (0, 1, 2, 3, 4, 5, 6), for P (Premium) family (1, 2, 3, 4)')
@allowed([
  0
  1
  2
  3
  4
  5
  6
])
param redisCacheCapacity int = 1

param tags object

@description('subnet id for private endpoint, if any')
param privateEndpointSubnetId string = ''
param privateLinkGroupIds array = ['redisCache']
param rgHub string = ''

@description('User Assigned Managed Identity Name')
param redisCacheManagedIdentityName string

resource redisCacheManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: redisCacheManagedIdentityName
}

resource redisCache 'Microsoft.Cache/redis@2022-05-01' = {
  name: redisCacheName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${redisCacheManagedIdentity.id}' : {}
    }
  }
  properties: {
    sku: {
      name: redisCacheSKU
      family: redisCacheFamily
      capacity: redisCacheCapacity
    }
    enableNonSslPort: true // non-SSL is needed for redis-cli used in scripts for now
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

//------------------------------------------------------------------------------
// create private endpoint is subnet id was given.
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = if (privateEndpointSubnetId != '') {
  name: '${redisCache.name}-pl'
  tags: tags
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${redisCache.name}-pl'
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: privateLinkGroupIds
        }
      }
    ]
  }
}

//------------------------------------------------------------------------------
// if kvName is provided then add the redisCache keys to the Key Vault.
// TODO: make these configurable
var keys = [
  'azfinsim-cache-key'
  'azfinsim-cache-name'
  'azfinsim-cache-ssl'
  // 'azfinsim-cache-port'
]

var secrets = {
  'azfinsim-cache-key': redisCache.listKeys().primaryKey
  'azfinsim-cache-name': redisCache.properties.hostName
  // 'azfinsim-cache-port': redisCache.properties.port //<-- this is non SSL port
  'azfinsim-cache-port': '6380'
  'azfinsim-cache-ssl': 'yes'
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if (kvName != '') {
  name: kvName
}

resource asecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = [for key in keys: if (kvName != '') {
  parent: keyVault
  name: key
  tags: tags
  properties: {
    value: secrets[key]
  }
}]

output privateEndpointIP string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
output privateEndpointFQDN string = privateEndpoint.properties.customDnsConfigs[0].fqdn

// add an entry in the global DNS zone
var privateDnsZoneName = 'privatelink.redis.cache.windows.net'
module deployEndpointAEntry '../../modules/networking/dnsZones/privateDnsZoneAEntry.bicep' = if (privateEndpointSubnetId != '') {
  name: 'deployEndpointAEntry-${redisCache.name}'
  params: {
    ipAddress: privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
    privateDnsZoneName: privateDnsZoneName
    serviceName: redisCache.name
  }
  scope: resourceGroup(rgHub)
}
