
## Installation

Required CLI tools:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform](https://developer.hashicorp.com/terraform/install)

### 1. Configure AZ CLI
```
az login
```

### 2. Save your Subscription ID & Tenant ID

```
az account list -o table
```
```
SUBSCRIPTION=your-subscription-id-here
TENANT_ID=your-tenant-id-here
```

### 3. Create a service principal

```
SERVICE_PRINCIPAL_JSON=$(az ad sp create-for-rbac --skip-assignment --name aks-terraform -o json)
```
```
SERVICE_PRINCIPAL=$(echo $SERVICE_PRINCIPAL_JSON | jq -r '.appId')
```
```
SERVICE_PRINCIPAL_SECRET=$(echo $SERVICE_PRINCIPAL_JSON | jq -r '.password')
```
```
az role assignment create --assignee $SERVICE_PRINCIPAL --scope "/subscriptions/$SUBSCRIPTION" --role Contributor
```
### 4. Run Terraform CMDS

```
terraform init
```

```
terraform plan -var serviceprincipal_id=$SERVICE_PRINCIPAL \
    -var serviceprincipal_key="$SERVICE_PRINCIPAL_SECRET" \
    -var tenant_id=$TENANT_ID \
    -var subscription_id=$SUBSCRIPTION
```

```
terraform apply -var serviceprincipal_id=$SERVICE_PRINCIPAL \
    -var serviceprincipal_key="$SERVICE_PRINCIPAL_SECRET" \
    -var tenant_id=$TENANT_ID \
    -var subscription_id=$SUBSCRIPTION
```
```
terraform destroy -var serviceprincipal_id=$SERVICE_PRINCIPAL \
    -var serviceprincipal_key="$SERVICE_PRINCIPAL_SECRET" \
    -var tenant_id=$TENANT_ID \
    -var subscription_id=$SUBSCRIPTION
```