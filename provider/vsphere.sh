REQUIRED_PROVIDER_VARIABLES=(
    VSPHERE_USERNAME
    VSPHERE_PASSWORD
    VSPHERE_SERVER
    VSPHERE_DATACENTER
    VSPHERE_DATASTORE
    VSPHERE_NETWORK
    VSPHERE_RESOURCE_POOL
    VSPHERE_FOLDER
    VSPHERE_TEMPLATE
    VSPHERE_STORAGE_POLICY
    CONTROL_PLANE_ENDPOINT_IP
    VSPHERE_TLS_THUMBPRINT
    VSPHERE_SSH_AUTHORIZED_KEY
    EXP_CLUSTER_RESOURCE_SET
    CPI_IMAGE_K8S_VERSION
)

function workload_precheck() {
    if ! type govc >/dev/null 2>&1; then
        echo "ERROR: govc not found"
        exit 1
    fi
    for VAR_NAME in ${REQUIRED_PROVIDER_VARIABLES[@]}; do
        if [[ -z "${!VAR_NAME}" ]]; then
            echo "ERROR: The following variables are required:"
            echo
            echo "export VSPHERE_SERVER=''             # XXX"
            echo "export VSPHERE_TLS_THUMBPRINT=''     # XXX"
            echo "export VSPHERE_USERNAME=''           # XXX"
            echo "export VSPHERE_PASSWORD=''           # XXX"
            echo "export VSPHERE_DATACENTER=''         # XXX"
            echo "export VSPHERE_DATASTORE=''          # XXX"
            echo "export VSPHERE_NETWORK=''            # XXX"
            echo "export VSPHERE_RESOURCE_POOL=''      # XXX"
            echo "export VSPHERE_FOLDER=''             # XXX"
            echo "export VSPHERE_TEMPLATE=''           # XXX"
            echo "export VSPHERE_STORAGE_POLICY=''     # XXX"
            echo "export VSPHERE_SSH_AUTHORIZED_KEY='' # XXX"
            echo "export CONTROL_PLANE_ENDPOINT_IP=''  # XXX"
            echo "export EXP_CLUSTER_RESOURCE_SET=''   # XXX"
            echo "export CPI_IMAGE_K8S_VERSION=''      # XXX"
            exit 1
        fi
    done
}

function workload_post_generate_hook() {
    true
}

function workload_pre_apply_hook() {
    local name=$1

    true
}

function workload_post_apply_hook() {
    local name=$1

    true
}

function workload_logs() {
    local name=$1

    kubectl --namespace capv-system logs deployment/capv-controller-manager \
    >capv-controller-manager.log
}