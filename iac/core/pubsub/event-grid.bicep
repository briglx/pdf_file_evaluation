@description('Specifies a project name that is used to generate the Event Grid name.')
param name string
param location string = resourceGroup().location
param storageAccountId string
param endpoint string
param createEventSubscription bool = false
param tags object = {}
param eventSubName string

resource systemTopic 'Microsoft.EventGrid/systemTopics@2021-10-15-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'None'
  }
  properties: {
    source: storageAccountId
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15' = if (createEventSubscription == true) {
  parent: systemTopic
  name: eventSubName
  properties: {
    destination: {
      properties: {
        resourceId: endpoint
        maxEventsPerBatch: 1
        preferredBatchSizeInKilobytes: 64
      }
      endpointType: 'AzureFunction'
    }
    filter: {
      advancedFilters: []
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
      ]
      enableAdvancedFilteringOnArrays: true
    }
  }
}

output systemTopicName string = systemTopic.name
