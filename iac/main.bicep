targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Application name')
param applicationName string

@minLength(1)
@description('Primary location for all resources')
param location string

var abbrs = loadJsonContent('./abbreviation.json')
var resourceToken = toLower(uniqueString(subscription().id, applicationName, location))
var tags = { 'app-name': applicationName}

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${applicationName}_${location}'
  location: location
  tags: tags
}

output RESOURCE_TOKEN string = resourceToken
output AZURE_RESOURCE_GROUP_NAME string = rg.name
