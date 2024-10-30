param name string
param location string = resourceGroup().location
param tags object = {}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  kind: 'string'
  properties: {
    appLogsConfiguration: {
      destination: 'string'
      logAnalyticsConfiguration: {
        customerId: 'string'
        sharedKey: 'string'
      }
    }
    customDomainConfiguration: {
      certificatePassword: 'string'
      certificateValue: any()
      dnsSuffix: 'string'
    }
    daprAIConnectionString: 'string'
    daprAIInstrumentationKey: 'string'
    daprConfiguration: {}
    infrastructureResourceGroup: 'string'
    kedaConfiguration: {}
    peerAuthentication: {
      mtls: {
        enabled: bool
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: bool
      }
    }
    vnetConfiguration: {
      dockerBridgeCidr: 'string'
      infrastructureSubnetId: 'string'
      internal: bool
      platformReservedCidr: 'string'
      platformReservedDnsIP: 'string'
    }
    workloadProfiles: [
      {
        maximumCount: int
        minimumCount: int
        name: 'string'
        workloadProfileType: 'string'
      }
    ]
    zoneRedundant: bool
  }
}
