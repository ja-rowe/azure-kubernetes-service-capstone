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
- `<svc>-test.yml`, `<svc>-build.yml` – the 16 pipeline definitions (a few lines each)
- `create-repos.sh` – creates the Azure Repos repositories and pushes the local service repos
- `terraform/` – the Azure DevOps configuration (ACR service connection, variable group,
  authorizations and the 16 pipelines)

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
