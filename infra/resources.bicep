@description('Name of the environment')
param environmentName string

@description('Location for all resources')
param location string

@description('Resource token for unique naming')
param resourceToken string

// Tags for all resources
var tags = {
  environment: environmentName
}

// User-Assigned Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'azid${resourceToken}'
  location: location
  tags: tags
}

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'azla${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'azacr${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

// AcrPull role assignment for managed identity
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, managedIdentity.id, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: containerRegistry
  properties: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  }
}

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'azcae${resourceToken}'
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
  }
}

// Container App for spring-petclinic
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'azca${resourceToken}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'spring-petclinic'
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        // CORS policy - configured for development. For production, restrict allowedOrigins to specific domains.
        corsPolicy: {
          allowedOrigins: ['https://*.azurecontainer.io', 'https://*.azurecontainerapps.io']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['Content-Type', 'Authorization', 'Accept']
        }
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'spring-petclinic'
          // AZD will replace this placeholder image with the actual application image during deployment
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'JAVA_OPTS'
              value: '-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
        rules: [
          {
            name: 'http-scale-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    acrPullRole
  ]
}

// Outputs
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = containerAppsEnvironment.name
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
