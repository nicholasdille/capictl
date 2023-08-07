REQUIRED_PROVIDER_VARIABLES=(
    HCLOUD_TOKEN
    HCLOUD_REGION
    HCLOUD_SSH_KEY
    HCLOUD_CONTROL_PLANE_MACHINE_TYPE
    HCLOUD_WORKER_MACHINE_TYPE
)

function workload_precheck() {
    for VAR_NAME in ${REQUIRED_PROVIDER_VARIABLES[@]}; do
        if [[ -z "${!VAR_NAME}" ]]; then
            echo "ERROR: The following variables are required:"
            echo
            echo "export HCLOUD_TOKEN=''                      # XXX"
            echo "export HCLOUD_REGION=''                     # XXX"
            echo "export HCLOUD_SSH_KEY=''                    # XXX"
            echo "export HCLOUD_CONTROL_PLANE_MACHINE_TYPE='' # XXX"
            echo "export HCLOUD_WORKER_MACHINE_TYPE=''        # XXX"
            exit 1
        fi
    done
}

function workload_post_generate_hook() {
    local name=$1

    sed -i '/pod-eviction-timeout/d' cluster.yaml
}

function workload_pre_apply_hook() {
    local name=$1

    kubectl create secret generic hetzner \
        --from-literal="hcloud=${HCLOUD_TOKEN}"
    kubectl create secret generic hcloud \
        --namespace=kube-system \
        --from-literal="token=${HCLOUD_TOKEN}"
}

function workload_post_apply_hook() {
    local name=$1

    true
}

function workload_control_plane_initialized_hook() {
    local name=$1

    helm repo add hcloud https://charts.hetzner.cloud
    helm repo update hcloud
    KUBECONFIG="kubeconfig-${name}" helm upgrade --install \
        --namespace kube-system \
        hccm hcloud/hcloud-cloud-controller-manager
}