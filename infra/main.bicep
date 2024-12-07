targetScope = 'resourceGroup'

var acrName = 'acr${uniqueString(resourceGroup().id)}'
var logAnalyticsWorkspaceName = 'log${uniqueString(resourceGroup().id)}'
var storageAccountName = 'st${uniqueString(resourceGroup().id)}'
var appQueueName = 'appimages'
var jobQueueName = 'jobimages'
var acaEnvName = 'cae-image-classifier'
var tagName = 'deploymentComplete'

var appsDemoFrontendAppName = 'frontend'
var appsDemoClassifierAppName = 'classifier-app'
var jobsDemoFrontendAppName = 'frontend-jobs'
var jobsDemoClassifierJobName = 'classifier-job'

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  sku: {
    name: 'Standard'
  }
  name: acrName
  location: resourceGroup().location
  tags: {}
  properties: {
    adminUserEnabled: false
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    anonymousPullEnabled: false
    metadataSearch: 'Enabled'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'

  resource queueService 'queueServices@2023-05-01' = {
    name: 'default'
    resource appQueue 'queues@2023-05-01' = {
      name: appQueueName
    }
    resource jobQueue 'queues@2023-05-01' = {
      name: jobQueueName
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: resourceGroup().location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource env 'Microsoft.App/managedEnvironments@2024-02-02-preview' = {
  name: acaEnvName
  location: resourceGroup().location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
         workloadProfileType: 'Consumption'
      }
    ]
  }
  identity: {
    type: 'SystemAssigned'
  }
}

var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, acrPullRoleId, env.id)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: env.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

module existingResources 'existing-resources.bicep' = {
  name: 'existingResources'
  params: {
    appsDemoFrontendAppName: appsDemoFrontendAppName
    jobsDemoFrontendAppName: jobsDemoFrontendAppName
    classifierAppName: appsDemoClassifierAppName
    classifierJobName: jobsDemoClassifierJobName
    tagName: tagName
  }
}

module appsDemoFrontendContainerApp 'frontend-container-app.bicep' = {
  name: 'appDemoFrontendContainerApp'
  params: {
    appName: appsDemoFrontendAppName
    envId: env.id
    containerImage: existingResources.outputs.appsDemoFrontendAppImage
    registryLoginServer: registry.properties.loginServer
    storageAccount: storageAccount
    queueName: appQueueName
  }
}

module jobsDemoFrontendContainerApp 'frontend-container-app.bicep' = {
  name: 'jobsDemoFrontendContainerApp'
  params: {
    appName: jobsDemoFrontendAppName
    envId: env.id
    containerImage: existingResources.outputs.appsDemoFrontendAppImage
    registryLoginServer: registry.properties.loginServer
    storageAccount: storageAccount
    queueName: jobQueueName
  }
}

module classifierApp 'classifier-app.bicep' = {
  name: 'classifierApp'
  params: {
    appName: appsDemoClassifierAppName
    frontendFqdn: appsDemoFrontendContainerApp.outputs.app.properties.configuration.ingress.fqdn
    envId: env.id
    containerImage: existingResources.outputs.appsDemoClassifierAppImage
    registryLoginServer: registry.properties.loginServer
    storageAccountName: storageAccountName
    storageAccount: storageAccount
    queueName: appQueueName
  }
}

module classifierJob 'classifier-job.bicep' = {
  name: 'classifierJob'
  params: {
    jobName: jobsDemoClassifierJobName
    frontendFqdn: jobsDemoFrontendContainerApp.outputs.app.properties.configuration.ingress.fqdn
    envId: env.id
    containerImage: existingResources.outputs.jobsDemoClassifierJobImage
    registryLoginServer: registry.properties.loginServer
    storageAccount: storageAccount
    storageAccountName: storageAccountName
    queueName: jobQueueName
  }
}

resource tags 'Microsoft.Resources/tags@2024-03-01' = {
  name: 'default'
  properties: {
    tags: {
      '${tagName}': 'true'
    }
  }
  dependsOn: [
    appsDemoFrontendContainerApp
    classifierApp
    jobsDemoFrontendContainerApp
    classifierJob
  ]
}

var storageQueueDataMessageSenderRoleId = 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'

resource appsFrontendQueueRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, storageQueueDataMessageSenderRoleId, resourceGroup().id, appsDemoFrontendAppName)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataMessageSenderRoleId)
    principalId: appsDemoFrontendContainerApp.outputs.app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource jobsFrontendQueueRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, storageQueueDataMessageSenderRoleId, resourceGroup().id, jobsDemoFrontendAppName)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataMessageSenderRoleId)
    principalId: jobsDemoFrontendContainerApp.outputs.app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

var storageQueueDataContributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
resource classifierQueueRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, storageQueueDataMessageSenderRoleId, resourceGroup().id, appsDemoClassifierAppName)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
    principalId: classifierApp.outputs.app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
resource classifierJobQueueRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, storageQueueDataMessageSenderRoleId, resourceGroup().id, jobsDemoClassifierJobName)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageQueueDataContributorRoleId)
    principalId: classifierJob.outputs.app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output ACR_NAME string = registry.name
output STORAGE_ACCOUNT_NAME string = storageAccount.name
output APPS_DEMO_FRONTEND_APP_NAME string = appsDemoFrontendAppName
output APPS_DEMO_CLASSIFIER_APP_NAME string = appsDemoClassifierAppName
output JOBS_DEMO_FRONTEND_APP_NAME string = jobsDemoFrontendAppName
output JOBS_DEMO_CLASSIFIER_JOB_NAME string = jobsDemoClassifierJobName
