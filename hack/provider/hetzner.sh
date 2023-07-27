function workload_precheck() {
    true
}

export HCLOUD_TOKEN="$(pp hcloud)"
export HCLOUD_REGION=fsn1
export HCLOUD_SSH_KEY=default
export HCLOUD_CONTROL_PLANE_MACHINE_TYPE=cx21
export HCLOUD_WORKER_MACHINE_TYPE=cx21

function workload_post_generate_hook() {
    true
}

function workload_pre_apply_hook() {
    kubectl create secret generic hetzner \
        --from-literal="hcloud=${HCLOUD_TOKEN}"
}

function workload_post_apply_hook() {
    exit
}