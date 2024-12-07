param jobName string
param frontendFqdn string
param envId string
param registryLoginServer string
param storageAccount object
param storageAccountName string
param queueName string
param containerImage string

resource classifierApp 'Microsoft.App/jobs@2024-08-02-preview' = {
  name: jobName
  location: resourceGroup().location
  properties: {
    environmentId: envId
    workloadProfileName: 'Consumption'
    configuration: {
      registries: [
        {
          server: registryLoginServer
          identity: 'system-environment'
        }
      ]
      replicaTimeout: 300
      triggerType: 'Event'
      eventTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
        scale: {
          minExecutions: 0
          maxExecutions: 25
          pollingInterval: 10
          rules: [
            {
              name: 'queue-scaler'
              type: 'azure-queue'
              identity: 'system'
              metadata: {
                queueName: queueName
                accountName: storageAccountName
                queueLength: '1'
              }
            }
          ]
        }
      }
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
            {
              name: 'RUN_ONCE'
              value: '1'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output app object = classifierApp
