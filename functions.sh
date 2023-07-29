function wait_for_control_plane_ready() {
    MAX_WAIT_SECONDS=$(( 30 * 60 ))
    SECONDS=0
    while test "${SECONDS}" -lt "${MAX_WAIT_SECONDS}"; do
        echo "### Waiting for control plane of workload cluster to be ready"
        clusterctl describe cluster ${CLUSTER_NAME}
        control_plane_ready="$(
            kubectl get cluster ${CLUSTER_NAME} --output json | \
                jq --raw-output '.status.conditions[] | select(.type == "ControlPlaneReady") | .status'
        )"
        if test "${control_plane_ready}" == "True"; then
            kubectl describe cluster ${CLUSTER_NAME}
            kubectl describe KubeadmControlPlane
            echo "### Control plane initialized"
            break
        fi
        sleep 60
    done
    if test "${control_plane_ready}" == "False"; then
        echo "### Control plane failed to initialize"
        return 1
    fi
}

function wait_for_control_plane_initialized() {
    MAX_WAIT_SECONDS=$(( 30 * 60 ))
    SECONDS=0
    while test "${SECONDS}" -lt "${MAX_WAIT_SECONDS}"; do
        echo "### Waiting for control plane of workload cluster to be ready"
        clusterctl describe cluster ${CLUSTER_NAME}
        control_plane_initialized="$(
            kubectl get cluster ${CLUSTER_NAME} --output json | \
                jq --raw-output '.status.conditions[] | select(.type == "ControlPlaneInitialized") | .status'
        )"
        if test "${control_plane_initialized}" == "True"; then
            kubectl describe cluster ${CLUSTER_NAME}
            kubectl describe KubeadmControlPlane
            echo "### Control plane initialized"
            break
        fi
        sleep 60
    done
    if test "${control_plane_initialized}" == "False"; then
        echo "### Control plane failed to initialize"
        return 1
    fi
}

function wait_for_workers_ready() {
    MAX_WAIT_SECONDS=$(( 30 * 60 ))
    SECONDS=0
    while test "${SECONDS}" -lt "${MAX_WAIT_SECONDS}"; do
        echo "### Waiting for workers of workload cluster to be ready"
        clusterctl describe cluster ${CLUSTER_NAME}
        worker_ready="$(
            kubectl get machinedeployment ${CLUSTER_NAME}-md-0 --output json | \
                jq --raw-output '.status.conditions[] | select(.type == "Ready") | .status'
        )"
        if test "${worker_ready}" == "True"; then
            echo "### Worker ready"
            break
        fi
        sleep 60
    done
    if test "${worker_ready}" == "False"; then
        echo "### Workers failed to initialize"
        kubectl describe machinedeployment ${CLUSTER_NAME}-md-0
        return 1
    fi
}

function wait_for_nodes_ready() {
    MAX_WAIT_SECONDS=$(( 30 * 60 ))
    SECONDS=0
    while test "${SECONDS}" -lt "${MAX_WAIT_SECONDS}"; do
        echo "### Waiting for nodes to be ready..."
        sleep 5
        if ! kubectl --kubeconfig kubeconfig-${CLUSTER_NAME} get nodes --output jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.reason=="KubeletReady")].status}{"\n"}{end}' | grep -qE "\sFalse$"; then
            echo "### All nodes are ready"
            break
        fi
    done
    if kubectl --kubeconfig kubeconfig-${CLUSTER_NAME} get nodes --output jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.reason=="KubeletReady")].status}{"\n"}{end}' | grep -qE "\sFalse$"; then
        kubectl --kubeconfig kubeconfig-${CLUSTER_NAME} describe nodes
        kubectl --kubeconfig kubeconfig-${CLUSTER_NAME} get pods -A
        echo "### Nodes are not ready"
        exit 1
    fi
}

function wait_for_pods_ready() {
    echo "### Initialize CAPV in workload cluster"
    clusterctl init --kubeconfig kubeconfig-${CLUSTER_NAME} --infrastructure vsphere --wait-provider-timeout 600 --v 5
    echo "### Waiting for management resources to be running"
    MAX_WAIT_SECONDS=$(( 30 * 60 ))
    SECONDS=0
    while test "${SECONDS}" -lt "${MAX_WAIT_SECONDS}"; do
        echo "### Waiting for all pods to be running..."
        if ! kubectl --kubeconfig kubeconfig-${CLUSTER_NAME} get pods -A | tail -n +2 | grep -vq Running; then
            echo "### All pods are ready"
            break
        fi
        sleep 10
    done
    if kubectl --kubeconfig kubeconfig-${CLUSTER_NAME} get pods -A | tail -n +2 | grep -vq Running; then
        echo "### Pods are not ready"
        return 1
    fi
}