az account set -s $AZURE_SUBSCRIPTION_ID

DATETIME=$(date '+%Y%m%d%H%M%S')
az acr build -r $ACR_NAME -t frontend:$DATETIME frontend

echo "Updating frontend container image to $ACR_NAME.azurecr.io/frontend:$DATETIME"
az containerapp update -n $APPS_DEMO_FRONTEND_APP_NAME -g $AZURE_RESOURCE_GROUP --image "$ACR_NAME.azurecr.io/frontend:$DATETIME"
az containerapp update -n $JOBS_DEMO_FRONTEND_APP_NAME -g $AZURE_RESOURCE_GROUP --image "$ACR_NAME.azurecr.io/frontend:$DATETIME"

az acr build -r $ACR_NAME -t classifier:$DATETIME classifier

echo "Updating classifier container image to $ACR_NAME.azurecr.io/classifier:$DATETIME"
az containerapp update -n $APPS_DEMO_CLASSIFIER_APP_NAME -g $AZURE_RESOURCE_GROUP --image "$ACR_NAME.azurecr.io/classifier:$DATETIME"
az containerapp job update -n $JOBS_DEMO_CLASSIFIER_JOB_NAME -g $AZURE_RESOURCE_GROUP --image "$ACR_NAME.azurecr.io/classifier:$DATETIME"