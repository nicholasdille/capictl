# Works for hetzner and vsphere
PROVIDER_NAMESPACE="$(k get ns --selector "cluster.x-k8s.io/provider=infrastructure-${WORKLOAD_PROVIDER}" --output name | xargs basename)
kubectl --namespace "${PROVIDER_NAMESPACE}" get deployments.apps --selector "cluster.x-k8s.io/provider=infrastructure-${WORKLOAD_PROVIDER}" --output name \
| xargs -I{} kubectl --namespace "${PROVIDER_NAMESPACE}" logs {}