
## Installation

Required CLI tools:

- [Azure DevOps Service](https://azure.microsoft.com/en-us/products/devops)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

1. ### Create Storage Account

This is where we will store the terraform state.

```
#!/bin/bash

RESOURCE_GROUP_NAME="aks-terraform"
STORAGE_ACCOUNT_NAME=tfstate$RANDOM
CONTAINER_NAME=tfstate

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

# Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME

az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv
```
2. ### Create Azure Container Registry

```
#!/bin/bash

RESOURCE_GROUP_NAME="aks-terraform"
CONTAINER_REGISTRY_NAME="sockshop1"

az acr create --resource-group $RESOURCE_GROUP_NAME \
  --name $CONTAINER_REGISTRY_NAME --sku Standard
```

3. ### Create Service Connections

Create connections for the following:
- ACR
- Azure Storage

4. ### Create the following variables in the Library
-  dockerRegistryServiceConnection
    - the value should be the name of the service connection
- containerRegistry
    - the value should be the name of the container registry
5. ### Import repos & Create pipelines

These are the repos containing the microservices that form the Sock Shop web app along with the Azure Pipeline YAMLS files.
- https://github.com/ja-rowe/user
- https://github.com/ja-rowe/shipping
- https://github.com/ja-rowe/queue-master
- https://github.com/ja-rowe/payment
- https://github.com/ja-rowe/orders
- https://github.com/ja-rowe/front-end
- https://github.com/ja-rowe/catalogue
- https://github.com/ja-rowe/carts
- https://github.com/ja-rowe/azure-kubernetes-service-deploy

6. ### Assign AcrPull permission
```
az login

az account list -o table

SUBSCRIPTION=your-subscription-id-here

SERVICE_PRINCIPAL_JSON=$(az ad sp create-for-rbac --skip-assignment --name <Name-Of-SP> -o json)

az role assignment create --assignee <ACR-Resource-ID> --scope "/subscriptions/$SUBSCRIPTION/resourceGroups/<RG-Name>/providers/Microsoft.ContainerRegistry/registries/<Name-Of-Registry>" --role AcrPull
```