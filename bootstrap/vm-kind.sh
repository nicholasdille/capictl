function bootstrap_precheck() {
    if test -z "${VM_KIND_NAME}"; then
        echo "ERROR: VM_KIND_NAME not set."
        exit 1
    fi
    
    if ! ssh "${VM_KIND_NAME}" true; then
        echo "ERROR: SSH connection to ${VM_KIND_NAME} failed."
        exit 1
    fi

    if ! ssh "${VM_KIND_NAME}" type kind >/dev/null 2>&1; then
        echo "ERROR: kind not found. Required by bootstrap provider."
        return 1
    fi
    if ! ssh "${VM_KIND_NAME}" type docker >/dev/null 2>&1; then
        echo "ERROR: docker not found"
        exit 1
    fi
    if ! ssh "${VM_KIND_NAME}" docker version >/dev/null 2>&1; then
        echo "ERROR: Docker daemon not working or accessible"
        exit 1
    fi
}

function bootstrap_exists() {
    local name=$1

    ssh "${VM_KIND_NAME}" \
        kind get clusters \
    | grep -q "${name}"
}

function bootstrap_create() {
    local name=$1

    if bootstrap_exists "${name}"; then
        echo "### Bootstrap cluster already exists"

    else
        echo "### Creaking bootstrap cluster"
        cat bootstrap/kind.yaml \
        | ssh "${VM_KIND_NAME}" \
            kind create cluster \
                --name "${name}" \
                --config - \
                --wait 5m
    fi
}

function bootstrap_delete() {
    local name=$1
    
    if bootstrap_exists "${name}"; then
        echo "### Deleting bootstrap cluster"
        ssh "${VM_KIND_NAME}" \
            kind delete cluster --name "${name}"
    fi

    kill "${VM_KIND_TUNNEL_PID}"
}

function bootstrap_kubeconfig() {
    local name=$1

    if bootstrap_exists "${name}"; then
        ssh "${VM_KIND_NAME}" \
            kind get kubeconfig --name "${name}" \
        >kubeconfig-bootstrap
    fi

    PORT="$(
        kubectl --kubeconfig=./kubeconfig-bootstrap config view --output=json \
        | jq --raw-output --arg name "${name}" '.clusters[] | select(.name == "kind-\($name)") | .cluster.server' \
        | cut -d: -f3
    )"
    VM_KIND_TUNNEL_PID="$(
        sh -c "echo \$\$ && exec ssh -fNL ${PORT}:localhost:${PORT} playground" \
        | head -n 1
    )"
}

function bootstrap_post_create_hook() {
    true
}

function bootstrap_post_init_hook() {
    true
}