// param principalId string
// param roleDefinitionId string
// param principalType string

// param resourceScopeName string
// @allowed([
//   'ResourceGroup'
//   'Registry'
// ])
// param resourceScopeType string
// param resourceScopeVersion string

// param registryName string

// var scope = {
//   Registry: 'Microsoft.ContainerRegistry/registries@2023-11-01-preview'
// }

// resource resourceScope 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
//   name: resourceScopeName
// }


// resource roleAssignment  'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(resourceScope.id, principalId, roleDefinitionId)
//   scope: resourceScope
//   properties: {
//     roleDefinitionId: roleDefinitionId
//     principalId: principalId
//     principalType: principalType
//   }
// }

// param resourceName string
// param resourceType string
param resourceId string
param name string
param roleDefinitionId string
param principalId string
param principalType string = ''
param description string
#disable-next-line no-unused-params
param roledescription string = '' // leave these for logging in the portal
param registryName string


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceId, registryName, 'AcrPullTestUserAssigned')
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
  }
}


// resource roleAssignment 'Microsoft.Resources/deployments@2021-04-01' = {
//   name: take('dp-RRA-${description}-${last(split(resourceId,'/'))}',64)
//   properties: {
//       mode: 'Incremental'
//       expressionEvaluationOptions: {
//           scope: 'Outer'
//       }
//       template: json(loadTextContent('genericRoleAssignment.json'))
//       parameters: {
//           scope: {
//               value: resourceId
//           }
//           name: {
//               value: name
//           }
//           roleDefinitionId: {
//               value: roleDefinitionId
//           }
//           principalId: {
//               value: principalId
//           }
//           principalType: {
//               value: principalType
//           }
//       }
//   }
// }

output resourceid string = resourceId
// output roleAssignmentId string = roleAssignment.properties.outputs.roleAssignmentId.value
output roleAssignmentId string = roleAssignment.id
