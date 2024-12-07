param appName string
param envId string
param registryLoginServer string
param storageAccount object
param queueName string
param containerImage string

resource frontendApp 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: appName
  location: resourceGroup().location
  properties: {
    environmentId: envId
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'Auto'
        stickySessions: {
          affinity: 'sticky'
        }
      }
      registries: [
        {
          server: registryLoginServer
          identity: 'system-environment'
        }
      ]
    }
    template: {
      containers: [
        {
          image: containerImage
          name: 'main'
          env: [
            {
              name: 'AZURE_QUEUE_SERVICE_URL'
              value: storageAccount.properties.primaryEndpoints.queue
            }
            {
              name: 'AZURE_STORAGE_STATIC_WEBSITE_URL'
              value: storageAccount.properties.primaryEndpoints.web
            }
            {
              name: 'AZURE_QUEUE_NAME'
              value: queueName
            }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output app object = frontendApp
