param appName string
param frontendFqdn string
param envId string
param registryLoginServer string
param storageAccount object
param storageAccountName string
param queueName string
param containerImage string

resource classifierApp 'Microsoft.App/containerApps@2024-08-02-preview' = {
  name: appName
  location: resourceGroup().location
  properties: {
    environmentId: envId
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
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
              name: 'AZURE_QUEUE_NAME'
              value: queueName
            }
            {
              name: 'FRONTEND_RESULT_URL'
              value: 'https://${frontendFqdn}/result'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 25
        cooldownPeriod: 30
        pollingInterval: 10
        rules: [
          {
            name: 'queue-scaler'
            azureQueue: {
              queueName: queueName
              accountName: storageAccountName
              identity: 'system'
              queueLength: 10
            }
          }
        ]
      }
      terminationGracePeriodSeconds: 30
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output app object = classifierApp
