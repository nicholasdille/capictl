#!/bin/bash
set -o errexit -o pipefail

if ! type jq 2>&1; then
    echo "ERROR: Missing jq. Aborting."
    false
fi
if ! type hcloud 2>&1; then
    echo "ERROR: Missing hcloud. Aborting."
    false
fi

if test -f .env; then
    source .env
fi

if test -z "${HCLOUD_TOKEN}"; then
    echo "ERROR: Missing environment variable HCLOUD_TOKEN. Aborting."
    false
fi
export HCLOUD_TOKEN

CLUSTER_NAME=$1
: "${CLUSTER_NAME:=my-cluster}"

echo "### Remove virtual machines"
hcloud server list --selector "caph-cluster-${CLUSTER_NAME}=owned" --output json \
| jq --raw-output '.[].name' \
| xargs --no-run-if-empty -n 1 hcloud server delete

echo "### Remove load balancer"
hcloud load-balancer list --selector "caph-cluster-${CLUSTER_NAME}=owned" --output json \
| jq --raw-output '.[].name' \
| xargs --no-run-if-empty -n 1 hcloud load-balancer delete

echo "### Remove placement groups"
hcloud placement-group list --selector "caph-cluster-${CLUSTER_NAME}=owned" --output json \
| jq --raw-output '.[].name' \
| xargs --no-run-if-empty -n 1 hcloud placement-group delete
