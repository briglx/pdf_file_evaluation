param location string = resourceGroup().location

param virtualNetworkName string
param vnetAddressPrefix string
param subnet1Name string
param subnet2Name string
param subnet1Prefix string
param subnet2Prefix string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnet1Name
        properties: {
          addressPrefix: subnet1Prefix
        }
      }
      {
        name: subnet2Name
        properties: {
          addressPrefix: subnet2Prefix
        }
      }
    ]
  }

  resource subnet1 'subnets' existing = {
    name: subnet1Name
  }

  resource subnet2 'subnets' existing = {
    name: subnet2Name
  }
}

output vnetResourceId string = virtualNetwork.id
output vnetName string = virtualNetwork.name
output vnetAddressPrefix string = virtualNetwork.properties.addressSpace.addressPrefixes[0]
output subnet1ResourceId string = virtualNetwork::subnet1.id
output subnet2ResourceId string = virtualNetwork::subnet2.id
