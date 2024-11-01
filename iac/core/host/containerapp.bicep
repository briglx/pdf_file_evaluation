param name string
param location string = resourceGroup().location
param tags object = {}
param environmentName string
param environmentRg string
param registryName string
param registryRg string

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: environmentName
  scope: resourceGroup(environmentRg)
}

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: registryName
  scope: resourceGroup(registryRg)
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    environmentId: environment.id
    configuration: {
      ingress: {
        targetPort: 5000
      }
      registries: [
        {
          identity: registry.id
          passwordSecretRef: 'refname'
          server: registry.properties.loginServer
          username: registry.properties.adminUserEnabled ? registry.listCredentials().username : ''
        }
      ]
      secrets: [
        {
          identity: 'refname'
          keyVaultUrl: environment.properties.keyVaultUrl
          name: 'refname'
        }
      ]
    }
  }
}
