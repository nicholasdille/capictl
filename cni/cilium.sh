function cni_precheck() {
    if ! type cilium >/dev/null 2>&1; then
        echo "ERROR: cilium not found"
        return 1
    fi
}

function cni_deploy() {
    local name=$1

    # Migrated to CAPI helm addon
}

function cni_post_install_hook() {
    local name=$1

    KUBECONFIG=kubeconfig-${name} \
    cilium status \
        --wait \
        --wait-duration 5m
}