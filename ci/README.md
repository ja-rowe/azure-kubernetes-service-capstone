# Service release path

One pair of pipelines per microservice repo. The pipeline definitions live **here**, not in the
service repositories.

```
push to <svc> main ──► <svc>-test ──(succeeds)──► <svc>-build ──► ACR  (sockshop1.azurecr.io/<repo>:<BuildId>, :latest)
                                                                      │
                                         azure-pipelines.yml (deploy) picks up the latest tag of each repo
```

| Pipeline | File | Trigger | What it does |
|---|---|---|---|
| `<svc>-test` | `ci/<svc>-test.yml` | push to `main` of the `<svc>` Azure Repos repository | Runs the unit tests; publishes the tested commit SHA as an artifact |
| `<svc>-build` | `ci/<svc>-build.yml` | `<svc>-test` completes **successfully** (stage `Test`) | Checks out exactly the tested SHA, builds the image(s) and pushes them to ACR |

Services: `carts`, `orders`, `shipping`, `queue-master`, `user`, `payment`, `catalogue`, `front-end`.

## Layout

- `templates/test-java.yml`, `test-go.yml`, `test-node.yml` – language-specific unit-test steps
- `templates/publish-sha.yml` – records the commit that was tested
- `templates/build-image.yml` – optional Maven package + `Docker@2 buildAndPush`
- `<svc>-test.yml`, `<svc>-build.yml` – the 16 CI pipeline definitions (a few lines each)
- `release-dev.yml`, `promote.yml` – delivery to dev and manual promotion (see below)
- `templates/azure-login.yml`, `resolve-images.yml`, `read-env-images.yml`, `deploy-env.yml` – delivery steps
- `create-repos.sh` – creates the Azure Repos repositories and pushes the local service repos
- `terraform/` – the Azure DevOps configuration (ACR service connection, variable group,
  authorizations and the 16 pipelines)

## Delivery: dev -> staging -> prod

```
<svc>-build succeeds ─► release-dev (automatic) ─► environment dev        namespace sock-shop-dev
promote (manual, target=staging) ─► environment staging   [branch control + approval]  sock-shop-staging
promote (manual, target=prod)    ─► environment prod      [branch control + approval]  sock-shop-prod
```

All three environments are namespaces on the one AKS cluster (`aks-terraform`); each has its own
Terraform state (`env-dev|staging|prod.tfstate`) and its own public front-end IP. The cluster is
managed by the root Terraform module, the application by [`envs/`](../envs).

| Pipeline | File | Trigger | What it does |
|---|---|---|---|
| `release-dev` | `ci/release-dev.yml` | any `<svc>-build` succeeds (branch `main`) | Resolves the newest image of every service from ACR **by digest**, deploys that set to `dev`, smoke-tests it |
| `promote` | `ci/promote.yml` | manual, parameter `environment` = `staging` or `prod` | Reads the image set running in the previous environment (dev for staging, staging for prod), deploys exactly that set, smoke-tests it |

**Same image everywhere.** Images are deployed as `registry/repo@sha256:...`. Each environment's
Terraform state outputs the `images` it runs; `promote` applies the source environment's output to
the target, so what reaches prod is byte-for-byte what ran in staging, and prod can only receive
what staging already runs.

**Only changes from `main`.** (1) test pipelines only trigger on `main`; (2) the build pipeline
fails unless the tested commit is an ancestor of the service repo's `main`, so every image in ACR
came from `main`; (3) the `staging` and `prod` environments have a **Branch control** check that
only allows runs from `refs/heads/main`.

**Approvals and checks** are configured on the environments (`ci/terraform/environments.tf`), not in
the YAML, and Azure DevOps evaluates them before the stage that uses the environment starts, in this
order: Branch control -> Approval -> Exclusive lock.

| Environment | Branch control | Approval | Exclusive lock |
|---|---|---|---|
| `dev` | - | - | yes (`runLatest`: a newer deploy supersedes a queued older one) |
| `staging` | `refs/heads/main` | the PAT owner (may approve their own run), 7 day timeout | yes (`sequential`) |
| `prod` | `refs/heads/main` | the PAT owner (may approve their own run), 7 day timeout | yes (`sequential`) |

### Promoting

```
az pipelines run --name promote --branch main --parameters environment=staging
# open the run, review the image digests in the Resolve stage summary, approve the Deploy stage
az pipelines run --name promote --branch main --parameters environment=prod
```

The image set is captured in the `Resolve` stage (shown in the run summary) and that exact set is
deployed once approved. A resource administrator can bypass a check; Azure DevOps records who did.

### One-time setup for delivery

- `terraform apply` in `ci/terraform` creates the environments, checks and the two pipelines
  (the YAML must already be on this repository's default branch).
- Authorize the `.env` secure file for the new pipelines (Pipelines > Library > Secure files > `.env`
  > Security, or "Permit" on the first run).
- The root module now only contains the cluster;
  the environments are created by the first `release-dev` run.
- Tearing an environment down: `terraform destroy` in `envs/` with that environment's state key
  and `-var environment=<env>`.

## What the tests run

| Service | Command (inside a container) |
|---|---|
| carts, orders, shipping, queue-master | `mvn -B test` on `maven:3.6-jdk-8` with MongoDB on localhost |
| user | `glide install && go test -vet=off $(glide novendor)` on Go 1.11 + `mongod` (the `db/mongodb` tests start a local `mongod`) |
| payment, catalogue | `gvt restore` (retried up to 3 times, the dependency clones are flaky) then `go test -vet=off` on `golang:1.11` |
| front-end | `npm install && npm test` on `node:10` |

`-vet=off` because `go test` runs `go vet` since Go 1.10 and the old tests contain printf-style
mistakes that vet reports as build failures.

Image repositories pushed (these are the names `azure-pipelines.yml` looks up):
`carts`, `orders`, `shipping`, `queuemaster`, `user`, `user-db`, `payment`, `catalogue`,
`catalogue-db`, `frontend`.

## One-time setup

Organisation `https://dev.azure.com/northwaylabs`, project `T2_T3`, GitHub service connection `ja-rowe`.

1. **Create and push the service repositories** (Azure DevOps only supports repository-resource CI
   triggers for Azure Repos Git). Store a PAT with Code (read & write) in a private file and run:

   ```
   AZDO_PAT_FILE=~/.azdo-pat ./ci/create-repos.sh
   ```

   It creates the 8 repositories if missing and pushes each local repo's `pipeline/acr-build`
   branch to `main` (the GitHub `origin` remote is untouched).
2. **Apply the Azure DevOps configuration** (service connection, variable group, pipelines):

   ```
   cd ci/terraform
   export AZDO_PERSONAL_ACCESS_TOKEN=$(cat ~/.azdo-pat)
   export AZDO_ORG_SERVICE_URL=https://dev.azure.com/northwaylabs
   export ARM_SUBSCRIPTION_ID=<subscription id>
   terraform init
   terraform import azuredevops_variable_group.aks_terraform T2_T3/<existing group id>   # only if the group exists
   terraform apply
   ```

   This creates the `acr-sockshop1` connection (workload identity federation, `AcrPush` on the
   registry), sets `containerRegistry` and `dockerRegistryServiceConnection` in the
   `aks-terraform` variable group, authorizes the connection/group/GitHub connection for
   pipelines, and creates `<svc>-test` and `<svc>-build` (names matter: the build pipelines
   reference the test pipelines by name). The YAML must be on this repository's default branch.

PAT scopes: Code (read & write), Project & Team (read), Build (read & execute), Variable Groups
(read, create & manage), Service Connections (read, query & manage).

## Notes

- The build pipeline checks out the SHA recorded by the test pipeline, so what is built is exactly
  what was tested even if `main` has moved on.
- A failing test run does not trigger the build (pipeline-resource triggers fire only on success).
- Only unit tests run today. The repositories' docker-based component/container/e2e tests are a
  later layer.
