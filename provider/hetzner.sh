function workload_precheck() {
    if test -z "${HCLOUD_TOKEN}"; then
        echo "ERROR: HCLOUD_TOKEN not set"
        return 1
    fi
    if test -z "${HCLOUD_REGION}"; then
        echo "ERROR: HCLOUD_REGION not set"
        return 1
    fi
    if test -z "${HCLOUD_SSH_KEY}"; then
        echo "ERROR: HCLOUD_SSH_KEY not set"
        return 1
    fi
    if test -z "${HCLOUD_CONTROL_PLANE_MACHINE_TYPE}"; then
        echo "ERROR: HCLOUD_CONTROL_PLANE_MACHINE_TYPE not set"
        return 1
    fi
    if test -z "${HCLOUD_WORKER_MACHINE_TYPE}"; then
        echo "ERROR: HCLOUD_WORKER_MACHINE_TYPE not set"
        return 1
    fi
}

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