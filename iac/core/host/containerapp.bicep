param name string
param location string = resourceGroup().location
param tags object = {}

param environmentName string
param environmentRg string

param registryName string
param registryRg string

param userAssignedIdentityName string
param containerName string
// param azureContainerRegistry string

var azureContainerRegistryImage = 'infra/ai.doc.eval.api_python'
var azureContainerRegistryImageTag = '2024.10.1.dev20241104T1942'

var cleanAppName = replace(replace(name, '-', ''), '_', '')

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: userAssignedIdentityName
  location: location
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: environmentName
  scope: resourceGroup(environmentRg)
}

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: registryName
  scope: resourceGroup(registryRg)
}

var acrPullDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'


// // Assign the 'acrpull' role to the managed identity of the Container App
// var acrpull = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var acrpullCaName = guid(registry.id, cleanAppName, acrPullDefinitionId)
module roleAssignment '../iam/roleassignment.bicep' = {
  name: '${name}-roleAssignment-acrpull'
  scope: resourceGroup(registryRg)
  params: {
    resourceId: registry.id
    description: 'acrpull'
    roledescription: 'acrpull'
    name: acrpullCaName
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', acrPullDefinitionId)
    registryName: registry.name
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}



resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: cleanAppName
  location: location
  tags: tags
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
    // type: 'SystemAssigned'
  }
  properties: {
    environmentId: environment.id
    configuration: {
      ingress: {
        targetPort: 5000
      }
      registries: [
        {
          // identity: 'system'
          identity: identity.id
          // server: registry.properties.loginServer
          server: '${registry.name}.azurecr.io'
        }
      ]
    }
    template: {
      containers: [
        {
          name: containerName
          image: '${registry.name}.azurecr.io/${azureContainerRegistryImage}:${azureContainerRegistryImageTag}'
          resources: {
              cpu: json('0.5')
              memory: '1.0Gi'
          }
          probes: [
            {
              type: 'startup'
              httpGet: {
                path: '/health'
                port: 5000
              }
              initialDelaySeconds: 3
              periodSeconds: 1
            }
            {
              type: 'readiness'
              httpGet: {
                path: '/health'
                port: 5000
              }
              initialDelaySeconds: 3
              periodSeconds: 5
            }
            {
              type: 'liveness'
              httpGet: {
                path: '/health'
                port: 5000
              }
              initialDelaySeconds: 7
              periodSeconds: 5
            }
          ]
        }
      ]
    }
  }
}

// output id string = containerApp.id
output name string = containerApp.name
output identityPrincipalId string = identity.properties.principalId
