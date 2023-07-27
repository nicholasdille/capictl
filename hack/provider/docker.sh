function workload_precheck() {
    if ! type docker >/dev/null 2>&1; then
        echo "ERROR: docker not found"
        exit 1
    fi
    if ! docker version >/dev/null 2>&1; then
        echo "ERROR: Docker daemon not working or accessible"
        exit 1
    fi
}

export CLUSTER_TOPOLOGY=true
export PROVIDER_TEMPLATE_FLAVOR=development

function workload_post_generate_hook() {
    true
}

function workload_pre_create_hook() {
    true
}