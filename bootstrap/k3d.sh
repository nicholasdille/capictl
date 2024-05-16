function bootstrap_precheck() {
    if ! type k3d >/dev/null 2>&1; then
        echo "ERROR: k3d not found. Required by bootstrap provider."
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

function bootstrap_create() {
    local name=$1

    if k3d cluster list | grep -q "${name}"; then
        echo "### Bootstrap cluster already exists"

    else
        echo "### Creaking bootstrap cluster"
        k3d cluster create "${name}" \
            --kubeconfig-update-default=false #\
            #--subnet "${POD_CIDR}" \
            #--volume "/var/run/docker.sock:/var/run/docker.sock"
    fi
}

function bootstrap_exists() {
    local name=$1

    k3d cluster list | grep -q "${name}"
}

function bootstrap_delete() {
    local name=$1
    
    if bootstrap_exists "${name}"; then
        echo "### Deleting bootstrap cluster"
        k3d cluster delete "${name}"
    fi
}

function bootstrap_kubeconfig() {
    local name=$1

    if bootstrap_exists "${name}"; then
        k3d kubeconfig get "${name}" >kubeconfig-bootstrap
    fi
}

function bootstrap_post_create_hook() {
    true
}

function bootstrap_post_init_hook() {
    true
}