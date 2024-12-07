az account set -s $AZURE_SUBSCRIPTION_ID

echo "Enabling static website on storage account $STORAGE_ACCOUNT_NAME"
az storage blob service-properties update --account-name $STORAGE_ACCOUNT_NAME --static-website

FILE999_EXISTS=$(az storage blob exists --name '999.jpg' --container-name '$web' --account-name $STORAGE_ACCOUNT_NAME -o tsv --query exists)

echo "FILE999_EXISTS: $FILE999_EXISTS"

if echo "$FILE999_EXISTS" | grep -q "false"; then
    echo "Uploading images to storage account $STORAGE_ACCOUNT_NAME"
    az storage blob upload-batch --destination '$web' --account-name $STORAGE_ACCOUNT_NAME --source images
else
    echo "Images already uploaded to storage account $STORAGE_ACCOUNT_NAME"
fi

sleep 2