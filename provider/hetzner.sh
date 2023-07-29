function workload_precheck() {
    true
}

export HCLOUD_TOKEN="$(pp hcloud)"
export HCLOUD_REGION=fsn1
export HCLOUD_SSH_KEY=default
export HCLOUD_CONTROL_PLANE_MACHINE_TYPE=cx21
export HCLOUD_WORKER_MACHINE_TYPE=cx21

function workload_post_generate_hook() {
    local name=$1

    sed -i '/pod-eviction-timeout/d' cluster.yaml
}

function workload_pre_apply_hook() {
    local name=$1

    KUBECONFIG="kubeconfig-${name}" kubectl create secret generic hetzner \
        --from-literal="hcloud=${HCLOUD_TOKEN}"
    KUBECONFIG="kubeconfig-${name}" kubectl create secret generic hcloud \
        --namespace=kube-system \
        --from-literal="token=${HCLOUD_TOKEN}"
}

function workload_post_apply_hook() {
    local name=$1

    helm repo add hcloud https://charts.hetzner.cloud
    helm repo update hcloud
    KUBECONFIG="kubeconfig-${name}" helm upgrade --install \
        --namespace kube-system \
        hccm hcloud/hcloud-cloud-controller-manager
}