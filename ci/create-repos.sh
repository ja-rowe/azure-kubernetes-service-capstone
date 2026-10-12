#!/usr/bin/env bash
# Creates the service repositories in Azure Repos (if missing) and pushes each local repo's
# branch to `main` there. The GitHub `origin` remote is not touched.
#
#   ORG=https://dev.azure.com/northwaylabs PROJECT=T2_T3 \
#   AZDO_PAT_FILE=~/.azdo-pat WORKSPACE=~/Documents/t3 ./ci/create-repos.sh
#
# Repository creation uses the `az devops login` session. The push needs the PAT: it is read from
# $AZDO_PERSONAL_ACCESS_TOKEN or from the file named by $AZDO_PAT_FILE and only ever passed to git
# in an HTTP header (never printed).
set -euo pipefail

ORG="${ORG:-https://dev.azure.com/northwaylabs}"
PROJECT="${PROJECT:-T2_T3}"
WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"
SOURCE_BRANCH="${SOURCE_BRANCH:-pipeline/acr-build}"
SERVICES=(carts orders shipping queue-master user payment catalogue front-end)

TOKEN="${AZDO_PERSONAL_ACCESS_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -n "${AZDO_PAT_FILE:-}" ]; then TOKEN="$(tr -d '\r\n' < "${AZDO_PAT_FILE/#\~/$HOME}")"; fi
: "${TOKEN:?set AZDO_PERSONAL_ACCESS_TOKEN or AZDO_PAT_FILE}"
HEADER="Authorization: Basic $(printf ':%s' "$TOKEN" | base64 | tr -d '\n')"
unset TOKEN

for svc in "${SERVICES[@]}"; do
  dir="$WORKSPACE/$svc"
  if az repos show --repository "$svc" --organization "$ORG" --project "$PROJECT" >/dev/null 2>&1; then
    echo "repo exists  $svc"
  else
    az repos create --name "$svc" --organization "$ORG" --project "$PROJECT" --output none
    echo "repo created $svc"
  fi
  url="$ORG/$PROJECT/_git/$svc"
  git -C "$dir" remote get-url azure >/dev/null 2>&1 || git -C "$dir" remote add azure "$url"
  git -C "$dir" -c "http.extraHeader=$HEADER" push azure "$SOURCE_BRANCH:main"
  echo "pushed       $svc ($(git -C "$dir" rev-parse --short "$SOURCE_BRANCH"))"
done
