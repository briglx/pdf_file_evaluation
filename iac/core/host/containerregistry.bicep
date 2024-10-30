@description('Provide a globally unique name of your Azure Container Registry')
param name string = ''
@description('Provide a tier of your Azure Container Registry.')
param acrSku string = ''
param location string = resourceGroup().location
param tags object = {}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
  }
}

@description('Output the login server property for later use')
output name string = containerRegistry.name
output loginServer string = containerRegistry.properties.loginServer
