param name string
param location string = resourceGroup().location
param tags object = {}

// Reference Resource params
param logAnalyticsWorkspaceName string
param logAnalyticsRgName string
param appSubnetId string

var cleanAppEnvName = replace(replace(name, '-', ''), '_', '')

// Reference Resource
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = if (!(empty(logAnalyticsWorkspaceName))) {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsRgName)
}

// App Environment
resource appEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: cleanAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: appSubnetId
      internal: true
    }
  }
}

output id string = appEnvironment.id
output name string = appEnvironment.name
