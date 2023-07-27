function bootstrap_precheck() {
    if ! type k3d >/dev/null 2>&1; then
        echo "ERROR: k3d not found. Required by bootstrap provider."
        return 1
    fi
}

function bootstrap_create() {
    local name=$1

    if k3d cluster list | grep -q "${name}"; then
        echo "### Bootstrap cluster already exists"

    else
        echo "### Creaking bootstrap cluster"
        k3d cluster create "${name}" \
            --k3s-arg "--disable=traefik@server:*" \
            --k3s-arg "--disable=servicelb@server:*" \
            --volume "/var/run/docker.sock:/var/run/docker.sock" \
            --wait --timeout 5m
    fi
}

function bootstrap_kubeconfig() {
    local name=$1

    k3d kubeconfig get "${name}" >kubeconfig-bootstrap
}

function bootstrap_delete() {
    local name=$1

    if k3d cluster list | grep -q "${name}"; then
        echo "### Deleting bootstrap cluster"
        k3d cluster delete "${name}"
    fi
}