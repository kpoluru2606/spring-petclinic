targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment used to generate a short unique hash for resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the resource group')
param resourceGroupName string = 'rg-${environmentName}'

// Generate resource token for unique naming
var resourceToken = uniqueString(subscription().id, location, environmentName)

// Tags applied to all resources
var tags = {
  'azd-env-name': environmentName
}

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Deploy main infrastructure
module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    environmentName: environmentName
    location: location
    resourceToken: resourceToken
  }
}

// Outputs required by AZD
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output RESOURCE_GROUP_ID string = rg.id
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = resources.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME
output AZURE_CONTAINER_REGISTRY_NAME string = resources.outputs.AZURE_CONTAINER_REGISTRY_NAME
