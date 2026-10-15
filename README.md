
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

4. ### Run the infrastructure pipeline

Run `azure-pipelines.yml` (the `infra` pipeline). It has two stages:
- `bootstrap`: provisions the Terraform remote state resource group, storage account and container, the `aks-terraform` resource group and the `sockshop1` Azure Container Registry. It is idempotent, so re-running is safe.
- `cluster`: `terraform init`, `validate`, `plan` and `apply` of the AKS cluster. The `action` parameter can be set to `destroy` to remove the cluster (destroy the environments first).

The pipeline also runs when infrastructure files are pushed to `main`.

One-time permission: the pipeline's service principal cannot create role assignments, so the
grants it needs (`AcrPull` on the registry for the cluster's service principal) live in the
[`access/`](access/main.tf) Terraform root, applied by an operator account after the cluster exists
(commands in `access/main.tf`).

5. ### Deploy the Sock Shop

The application is not deployed by the infrastructure pipeline. Each environment (dev, staging,
prod) is a namespace on the cluster, deployed by `release-dev` (automatic after a service build
succeeds) and `promote` (manual, gated). See [`ci/README.md`](ci/README.md#delivery-dev---staging---prod).

## Optional: build your own images into ACR

Each microservice has a test pipeline (runs on merge to `main`) and a build pipeline (triggered
when the tests pass) that pushes the image to ACR. Their definitions live in [`ci/`](ci/README.md),
together with the one-time setup (importing the service repos into Azure Repos, the ACR service
connection and creating the pipelines).

When the registry has image tags, `azure-pipelines.yml` picks up the latest tag of each repository
automatically.
