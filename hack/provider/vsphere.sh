function workload_precheck() {
    if ! type govc >/dev/null 2>&1; then
        echo "ERROR: govc not found"
        exit 1
    fi
}

export POD_CIDR="10.42.128.0/17"
export SERVICE_CIDR="10.42.0.0/18"

if test -z "${VSPHERE_USERNAME}"; then
    VSPHERE_USERNAME="$(ph vcenter-username)"
fi
export VSPHERE_USERNAME

if test -z "${VSPHERE_PASSWORD}"; then
    VSPHERE_PASSWORD="$(ph vcenter-password)"
fi
export VSPHERE_PASSWORD

export VSPHERE_SERVER=""
export VSPHERE_DATACENTER=""
export VSPHERE_DATASTORE=""
export VSPHERE_NETWORK=""
export VSPHERE_RESOURCE_POOL=""
export VSPHERE_FOLDER=""
export VSPHERE_TEMPLATE=""
export VSPHERE_STORAGE_POLICY=""
export CONTROL_PLANE_ENDPOINT_IP=""
#export VIP_NETWORK_INTERFACE=""
export VSPHERE_TLS_THUMBPRINT=""
export VSPHERE_SSH_AUTHORIZED_KEY=""
export EXP_CLUSTER_RESOURCE_SET="true"
export CPI_IMAGE_K8S_VERSION="v1.27.0"

function workload_post_generate_hook() {
    true
}

function workload_pre_apply_hook() {
    kubectl patch configmap coredns \
        --kubeconfig=kubeconfig-bootstrap \
        --namespace=kube-system \
        --patch-file=Corefile
    # TODO: Test DNS
    # TODO: Fix CSI configuration
}

function workload_post_apply_hook() {
    true
}