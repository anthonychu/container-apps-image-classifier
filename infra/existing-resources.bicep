param appsDemoFrontendAppName string
param jobsDemoFrontendAppName string
param classifierAppName string
param classifierJobName string
param tagName string

var resourcesExist = contains(resourceGroup().tags, tagName) && resourceGroup().tags[tagName] == 'true'

resource existingAppsDemoFrontendApp 'Microsoft.App/containerApps@2024-02-02-preview' existing = if (resourcesExist) {
  name: appsDemoFrontendAppName
}

resource existingJobsDemoFrontendApp 'Microsoft.App/containerApps@2024-02-02-preview' existing = if (resourcesExist) {
  name: jobsDemoFrontendAppName
}

resource existingAppsDemoClassifierApp 'Microsoft.App/containerApps@2024-02-02-preview' existing = if (resourcesExist) {
  name: classifierAppName
}

resource existingJobsDemoClassifierJob 'Microsoft.App/jobs@2024-02-02-preview' existing = if (resourcesExist) {
  name: classifierJobName
}

var appsDemoFrontendAppImage = resourcesExist ? existingAppsDemoFrontendApp.properties.template.containers[0].image : 'mcr.microsoft.com/k8se/quickstart:latest'
var appsDemoClassifierAppImage = resourcesExist ? existingAppsDemoClassifierApp.properties.template.containers[0].image : 'mcr.microsoft.com/k8se/quickstart:latest'
var jobsDemoFrontendAppImage = resourcesExist ? existingJobsDemoFrontendApp.properties.template.containers[0].image : 'mcr.microsoft.com/k8se/quickstart:latest'
var jobsDemoClassifierJobImage = resourcesExist ? existingJobsDemoClassifierJob.properties.template.containers[0].image : 'mcr.microsoft.com/k8se/quickstart-jobs:latest'

output appsDemoFrontendAppImage string = appsDemoFrontendAppImage
output appsDemoClassifierAppImage string = appsDemoClassifierAppImage
output jobsDemoFrontendAppImage string = jobsDemoFrontendAppImage
output jobsDemoClassifierJobImage string = jobsDemoClassifierJobImage

