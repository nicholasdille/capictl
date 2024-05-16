function bootstrap_precheck() {
    if ! type kind >/dev/null 2>&1; then
        echo "ERROR: kind not found. Required by bootstrap provider."
        return 1
    fi
    if ! type docker >/dev/null 2>&1; then
        echo "ERROR: docker not found"
        exit 1
    fi
    if ! docker version >/dev/null 2>&1; then
        echo "ERROR: Docker daemon not working or accessible"
        exit 1
    fi
}

function bootstrap_exists() {
    local name=$1

    kind get clusters | grep -q "${name}"
}

function bootstrap_create() {
    local name=$1

    if ! bootstrap_exists "${name}"; then
        echo "### Bootstrap cluster already exists"

    else
        echo "### Creaking bootstrap cluster"
        kind create cluster \
            --name "${name}" \
            --config bootstrap/kind.yaml \
            --wait 5m
    fi
}

function bootstrap_delete() {
    local name=$1
    
    if bootstrap_exists "${name}"; then
        echo "### Deleting bootstrap cluster"
        kind delete cluster --name "${name}"
    fi
}

function bootstrap_kubeconfig() {
    local name=$1

    if bootstrap_exists "${name}"; then
        kind get kubeconfig --name "${name}" >kubeconfig-bootstrap
    fi
}

function bootstrap_post_create_hook() {
    true
}

function bootstrap_post_init_hook() {
    true
}