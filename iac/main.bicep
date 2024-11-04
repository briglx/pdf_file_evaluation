targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Application name')
param applicationName string

@minLength(1)
@description('Primary location for all resources')
param location string

param connectivityRGName string
param coreVnetName string
param coreVnetPrefix string
param appSubnetName string

param commonRGName string
param commonAcrName string
param commonLogAnalyticsName string
param commonAppInsightsName string

var abbrs = loadJsonContent('./abbreviation.json')
var resourceToken = toLower(uniqueString(subscription().id, applicationName, location))
var tags = { 'app-name': applicationName}
param baseTime string = utcNow('u')

// Connectivity RG
resource rg_connectivity 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(connectivityRGName)
    ? connectivityRGName
    : '${abbrs.resourcesResourceGroups}_connectivity_${location}'
  location: location
  tags: tags
}

// Core Vnet
resource coreVnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = if (!(empty(coreVnetName))) {
  scope: rg_connectivity
  name: coreVnetName
}
var vnetExists = !empty(coreVnet.id)
module vnet './core/connectivity/vnet.bicep' = if (!vnetExists) {
  name: '${deployment().name}-vnet'
  scope: rg_connectivity
  params: {
    virtualNetworkName: !empty(coreVnetName) ? coreVnetName : '${abbrs.networkVirtualNetworks}-core-${location}'
    vnetAddressPrefix: !empty(coreVnetPrefix) ? coreVnetPrefix : '10.2.0.0/16'
    subnet1Name: 'snet-prv-endpoint'
    subnet1Prefix: '10.2.0.64/26'
    subnet2Name: !empty(appSubnetName) ? appSubnetName : 'snet-app'
    subnet2Prefix: '10.2.2.0/23'
  }
}
resource appSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = if (vnetExists) {
  name: appSubnetName
  scope: rg_connectivity
}
var coreVirtualNetworkId = !empty(coreVnet.id) ? coreVnet.id : vnet.outputs.subnet1ResourceId
var coreVirtualNetworkName = !empty(coreVnet.id) ? coreVnet.name : vnet.outputs.vnetName
var coreVirtualNetworkPrefix = !empty(coreVnet.id) ? coreVnet.properties.addressSpace.addressPrefixes[0] : vnet.outputs.vnetAddressPrefix
var appSubnetId = !empty(coreVnet.id) ? appSubnet.id : vnet.outputs.subnet2ResourceId

/////////// Common ///////////
// Common Resource Group
resource commonRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: commonRGName
}
var rg_commonExists = !empty(commonRg.id)
resource rg_common 'Microsoft.Resources/resourceGroups@2021-04-01' = if (!rg_commonExists) {
  name: !empty(commonRGName)
    ? commonRGName
    : '${abbrs.resourcesResourceGroups}_common_${location}'
  location: location
  tags: tags
}
var commonRgName = !empty(commonRg.id) ? commonRg.name : rg_common.name

// Azure Container Registry
resource commonRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  scope: rg_common
  name: commonAcrName
}
var registryExists = !empty(commonRegistry.id)
module containerRegistry './core/host/containerregistry.bicep' = if (!registryExists) {
  name: 'containerRegistry'
  scope: rg_common
  params: {
    name: !empty(commonAcrName) ? commonAcrName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    acrSku: 'Basic'
  }
}
var containerRegistryName = !empty(commonRegistry.id) ? commonRegistry.name : containerRegistry.outputs.name
var containerRegistryLoginServer = !empty(commonRegistry.id) ? commonRegistry.properties.loginServer : containerRegistry.outputs.loginServer

// Log Analytics workspace
resource commonLogAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  scope: rg_common
  name: commonLogAnalyticsName
}
var workspaceExists = !empty(commonLogAnalytics.id)
module logAnalytics './core/monitor/loganalytics.bicep' = if (!workspaceExists) {
  name: 'logAnalytics'
  scope: rg_common
  params: {
    name: !empty(commonLogAnalyticsName) ? commonLogAnalyticsName : '${abbrs.operationalInsightsWorkspaces}Default-${rg_common.location}'
    location: location
    tags: tags
  }
}
var logAnalyticsName = !empty(commonLogAnalytics.id) ? commonLogAnalytics.name : logAnalytics.outputs.name
var logAnalyticsWorkspaceId = !empty(commonLogAnalytics.id) ? commonLogAnalytics.id : logAnalytics.outputs.id
var logAnalyticsPrimaryKey = !empty(commonLogAnalytics.id) ? commonLogAnalytics.listKeys().primarySharedKey : logAnalytics.outputs.primaryKey

// App Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  scope: rg_common
  name: commonAppInsightsName
}
var applicationInsightsExists = !empty(applicationInsights.id)
module appInsights './core/monitor/applicationinsights.bicep' = if (!applicationInsightsExists) {
  name: 'appInsights'
  scope: rg_common
  params: {
    name: !empty(commonAppInsightsName) ? commonAppInsightsName : '${abbrs.insightsComponents}-default-${rg_common.location}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}
var appInsightsName = !empty(applicationInsights.id) ? applicationInsights.name : appInsights.outputs.name


////////////// App Specific Resources //////////////
// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${applicationName}_${location}'
  location: location
  tags: tags
}

// Container App Environment
var appEnvName = '${abbrs.appManagedEnvironments}${applicationName}_${location}'
module environment './core/host/managedEnvironment.bicep' = {
  name: 'containerAppEnv'
  scope: rg
  params: {
    name: appEnvName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsName
    logAnalyticsRgName: commonRgName
    appSubnetId: appSubnet.id
  }
}

module containerApp './core/host/containerapp.bicep' = {
  name: 'containerApp'
  scope: rg
  params: {
    name: '${abbrs.appContainerApps}${applicationName}_${location}'
    location: location
    tags: tags
    environmentName: appEnvName
    environmentRg: rg.name
    registryName: containerRegistryName
    registryRg: commonRgName
  }
}
// // Container App
// resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
//   name: '${abbrs.appContainerApps}${applicationName}_${location}'
//   location: location
//   tags: tags
//   properties: {
//     environment: {
//       id: environment.outputs.id
//     }
//     containerConfiguration: {
//       containerRegistry: {
//         id: commonRegistry.id
//       }
//       image: {
//         name: 'nginx'
//         tag: 'latest'
//       }
//     }
//   }
// }

output RESOURCE_TOKEN string = resourceToken
output AZURE_RESOURCE_GROUP_NAME string = rg.name

output AZURE_CONNECTIVITY_RG_NAME string = coreVnetName
output vnetExists bool = vnetExists
output VNET_CORE_ID string = coreVirtualNetworkId
output VNET_CORE_NAME string = coreVirtualNetworkName
output VNET_CORE_PREFIX string = coreVirtualNetworkPrefix
output APP_SUBNET_ID string = appSubnetId

output AZURE_COMMON_RG_NAME string = commonRgName
output ACR_NAME string = containerRegistryName
output ACR_URL string = containerRegistryLoginServer
output workspaceExists bool = workspaceExists
output LOG_ANALYTICS_NAME string = logAnalyticsName
output LOG_ANALYTICS_WORKSPACE_ID string = logAnalyticsWorkspaceId
output LOG_ANALYTICS_PRIMARY_KEY string = logAnalyticsPrimaryKey
output APP_INSIGHTS_NAME string = appInsightsName

output APP_ENVIRONMENT_ID string = environment.outputs.id
output APP_ENVIRONMENT_NAME string = environment.outputs.name
output baseTime string = baseTime
