REQUIRED_PROVIDER_VARIABLES=(
    HCLOUD_REGION
    HCLOUD_SSH_KEY
    HCLOUD_CONTROL_PLANE_MACHINE_TYPE
    HCLOUD_WORKER_MACHINE_TYPE
)

function workload_precheck() {
    if ! type hcloud >/dev/null 2>&1; then
        echo "ERROR: hcloud not found"
        return 1
    fi

    if test -z "${HCLOUD_TOKEN}"; then
        echo "ERROR: Missing HCLOUD_TOKEN. Aborting."
        exit 1
    fi
    export HCLOUD_TOKEN

    if test -z "${HCLOUD_SSH_KEY}"; then
        HCLOUD_SSH_KEY=caph

        SSH_KEY_JSON="$( hcloud ssh-key list --selector type=caph --output json )"
        if test "$( jq 'length' <<<"${SSH_KEY_JSON}" )" -eq 0; then
            echo "### Create and upload SSH key"
            rm -f ssh ssh.pub
            ssh-keygen -f ssh -t ed25519 -N ''
            hcloud ssh-key create --name caph --label type=caph --public-key-from-file ./ssh.pub

        elif test "$( jq 'length' <<<"${SSH_KEY_JSON}" )" -eq 1; then
            echo "### Use existing SSH key"
            if ! test -f ssh; then
                echo "ERROR: Missing ssh private key. Aborting."
                return 1
            fi

        else
            echo "ERROR: No or exactly one SSH key with label type=caph is required. Aborting."
            return 1

        fi
    fi
    export HCLOUD_SSH_KEY

    : "${HCLOUD_REGION:=fsn1}"
    : "${HCLOUD_CONTROL_PLANE_MACHINE_TYPE:=cpx21}"
    : "${HCLOUD_WORKER_MACHINE_TYPE:=cpx21}"
    export HCLOUD_REGION
    export HCLOUD_CONTROL_PLANE_MACHINE_TYPE
    export HCLOUD_WORKER_MACHINE_TYPE

    for VAR_NAME in ${REQUIRED_PROVIDER_VARIABLES[@]}; do
        if [[ -z "${!VAR_NAME}" ]]; then
            echo "ERROR: The following variables are required:"
            echo
            echo "export HCLOUD_TOKEN=''                      # XXX"
            echo "export HCLOUD_REGION=''                     # XXX"
            echo "export HCLOUD_SSH_KEY=''                    # XXX"
            echo "export HCLOUD_CONTROL_PLANE_MACHINE_TYPE='' # XXX"
            echo "export HCLOUD_WORKER_MACHINE_TYPE=''        # XXX"
            return 1
        fi
    done

    if test -z "${IMAGE_NAME}"; then
        IMAGE_NAME="$(
            hcloud image list --selector caph-image-name --output json \
            | jq --raw-output 'sort_by(.created) | .[-1] | select(.labels."caph-image-name") | .labels."caph-image-name"'
        )"
    fi
    echo "### Using image ${IMAGE_NAME}"
}

function workload_post_generate_hook() {
    local name=$1

    sed -i '/pod-eviction-timeout/d' cluster.yaml
}

function workload_pre_apply_hook() {
    local name=$1

    echo "### Prepare credentials"
    if ! kubectl get secret hetzner >/dev/null 2>&1; then
        kubectl create secret generic hetzner --from-literal=hcloud="${HCLOUD_TOKEN}"

    else
        kubectl patch secret hetzner --patch-file <(cat <<EOF
data:
  hcloud: $(echo -n "${HCLOUD_TOKEN}" | base64 -w0)
EOF
    )
    fi
    kubectl patch secret hetzner --patch '{"metadata":{"labels":{"clusterctl.cluster.x-k8s.io/move":""}}}'

    yq --inplace eval 'select(.kind == "Cluster").metadata.labels.hcloudCcmChart = "enabled"' cluster.yaml
    yq --inplace eval 'select(.kind == "Cluster").metadata.labels.hcloudCsiChart = "enabled"' cluster.yaml
}

function workload_post_apply_hook() {
    local name=$1

    true
}

function workload_control_plane_initialized_hook() {
    local name=$1

    # Migrated to CAPI helm addon
}

function workload_logs() {
    local name=$1

    kubectl --namespace caph-system logs deployment/caph-controller-manager \
    >caph-controller-manager.log
}