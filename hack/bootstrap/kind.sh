function bootstrap_precheck() {
    if ! type kind >/dev/null 2>&1; then
        echo "ERROR: kind not found. Required by bootstrap provider."
        return 1
    fi
}

function bootstrap_create() {
    local name=$1

    if kind get clusters | grep -q "${name}"; then
        echo "### Bootstrap cluster already exists"

    else
        echo "### Creaking bootstrap cluster"
        kind create cluster \
            --name "${name}" \
            --config bootstrap.yaml \
            --wait 5m
    fi
}

function bootstrap_kubeconfig() {
    local name=$1

    kind get kubeconfig --name "${name}" >kubeconfig-bootstrap
}

function bootstrap_delete() {
    local name=$1

    if kind get clusters | grep -q "${name}"; then
        echo "### Deleting bootstrap cluster"
        kind delete cluster --name "${name}"
    fi
}