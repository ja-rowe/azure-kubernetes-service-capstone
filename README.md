
## Installation

Required CLI tools:

- [Azure DevOps Service](https://azure.microsoft.com/en-us/products/devops)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

1. ### Upload the `.env` secure file

Upload a secure file named `.env` (Pipelines > Library > Secure files) and authorize the pipelines to use it. It must define the service principal used for all Azure access:

```
ARM_CLIENT_ID=
ARM_CLIENT_SECRET=
ARM_TENANT_ID=
ARM_SUBSCRIPTION_ID=
```

The service principal needs `Contributor` and permission to create role assignments (`User Access Administrator` or `Owner`) on the subscription.

2. ### Create the following variables in the Library
Create a variable group named `aks-terraform` containing:
- containerRegistry
    - the login server of the container registry, e.g. `sockshop1.azurecr.io`

3. ### Create the pipeline

Create a pipeline from `azure-pipelines.yml` in the `azure-kubernetes-service-deploy` repo. On a new Azure DevOps organization, make sure a Microsoft-hosted parallel job has been granted.

4. ### Run the pipeline

Run `azure-pipelines.yml`. It has four stages:
- `bootstrap`: provisions the Terraform remote state resource group, storage account and container, the `aks-terraform` resource group, the `sockshop1` Azure Container Registry, and the `AcrPull` role assignment for the service principal. It is idempotent, so re-running is safe.
- `tfvalidate`: runs `terraform init` and `terraform validate`.
- `deploy`: plans and applies the cluster and Sock Shop.
- `destroy`: runs `terraform destroy`. Comment out this whole stage in the YAML to keep the infra up after a run.
- At the end of `deploy`, the `Get Sock Shop external IP` step prints the public URL of the shop. The shop is only reachable while the infra exists, so comment out the `destroy` stage to browse it.

By default the pipeline deploys the public `weaveworksdemos` images. To deploy your own images instead, see the optional steps below.

## Optional: build your own images into ACR

1. Create a service connection to the ACR and add a `dockerRegistryServiceConnection` variable (the connection's name) to the `aks-terraform` variable group.
2. Import the repos containing the microservices that form the Sock Shop web app along with their Azure Pipeline YAML files, and create a pipeline for each:
- https://github.com/ja-rowe/user
- https://github.com/ja-rowe/shipping
- https://github.com/ja-rowe/queue-master
- https://github.com/ja-rowe/payment
- https://github.com/ja-rowe/orders
- https://github.com/ja-rowe/front-end
- https://github.com/ja-rowe/catalogue
- https://github.com/ja-rowe/carts
- https://github.com/ja-rowe/azure-kubernetes-service-deploy

When the registry has image tags, `azure-pipelines.yml` picks up the latest tag of each repository automatically.
