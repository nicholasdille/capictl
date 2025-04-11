function github_get_rate_limit() {
    if test -n "${GITHUB_TOKEN}"; then
        GITHUB_TOKEN_AUTH="Authorization: token ${GITHUB_TOKEN}"
    fi
    curl \
        --silent \
        --location \
        --fail \
        --header "${GITHUB_TOKEN_AUTH}" \
        --url https://api.github.com/rate_limit \
    | jq --raw-output '.rate.remaining'
}

function bootstrap_cluster_init() {
    echo "### Installing provider"
    clusterctl init \
        --infrastructure="${INFRASTRUCTURE_PROVIDER}" \
        --bootstrap="${BOOTSTRAP_PROVIDER}" \
        --control-plane="${CONTROL_PLANE_PROVIDER}" \
        --addon=helm \
        --wait-providers \
        --wait-provider-timeout=300
}

function generate_cluster_manifests() {
    echo "### Generating cluster configuration"
    if test -n "${PROVIDER_TEMPLATE_FLAVOR}"; then
        PROVIDER_TEMPLATE_FLAVOR_PARAMETER="--flavor ${PROVIDER_TEMPLATE_FLAVOR}"
    fi
    if ! ${REUSE_CLUSTER_YAML}; then
        rm -f cluster.yaml
    fi
    if ! test -f cluster.yaml; then
        clusterctl generate cluster "${CLUSTER_NAME}" \
            --kubernetes-version="v${KUBERNETES_VERSION}" \
            ${PROVIDER_TEMPLATE_FLAVOR_PARAMETER} \
            --control-plane-machine-count="${CONTROL_PLANE_NODE_COUNT}" \
            --worker-machine-count="${WORKER_NODE_COUNT}" \
            >cluster.yaml
    fi
    if test -n "${POD_CIDR}"; then
        export POD_CIDR
        yq --inplace eval 'select(.kind == "Cluster").spec.clusterNetwork.pods.cidrBlocks |= [env(POD_CIDR)]' cluster.yaml
    fi
    if test -n "${SERVICE_CIDR}"; then
        export SERVICE_CIDR
        yq --inplace eval 'select(.kind == "Cluster").spec.clusterNetwork.services.cidrBlocks |= [env(SERVICE_CIDR)]' cluster.yaml
    fi
    if ${OIDC_AUTH} && test -f auth-config.yaml; then
        yq --inplace eval 'select(.kind == "KubeadmControlPlane").spec.kubeadmConfigSpec.files |= [{"content": load(auth-config.yaml), "owner": "root:root", "path": "/etc/kubernetes/auth/auth-config.yaml", "permission": "0600}]' cluster.yaml
        yq --inplace eval 'select(.kind == "KubeadmControlPlane").spec.kubeadmConfigSpec.clusterConfiguration.apiServer.extraArgs.authentication-config = "/etc/kubernetes/auth/auth-config.yaml"' cluster.yaml
    fi
    export CNI_PLUGIN
    yq --inplace eval 'select(.kind == "Cluster").metadata.labels.cniChart = env(CNI_PLUGIN)' cluster.yaml
    yq --inplace eval 'select(.kind == "Cluster").metadata.labels.clusterApiVisualizerChart = "enabled"' cluster.yaml
    yq --inplace eval 'select(.kind == "Cluster").metadata.labels.kyvernoChart = "enabled"' cluster.yaml
    yq --inplace eval 'select(.kind == "Cluster").metadata.labels.traefikChart = "enabled"' cluster.yaml
    yq --inplace eval 'select(.kind == "Cluster").metadata.labels.headlampChart = "enabled"' cluster.yaml
    yq --inplace eval 'select(.kind == "Cluster").metadata.labels.metricsServerChart = "enabled"' cluster.yaml
}

function apply_cluster_manifests() {
    cat cluster.yaml \
    | kubectl apply -f -
    kubectl apply --filename=helm/*.yaml
}

function wait_for_control_plane_initialized() {
    echo "### Waiting for control plane to initialize"
    if ! kubectl wait cluster ${CLUSTER_NAME} --for=condition=ControlPlaneInitialized --timeout=${TIMEOUT_IN_MINUTES}m; then
        echo "ERROR: Control plane failed to initialize"
        clusterctl describe cluster ${CLUSTER_NAME} --show-conditions=all
        exit 1
    fi
}

function wait_for_control_plane_ready() {
    echo "### Waiting for control plane to be ready"
    if ! kubectl wait cluster ${CLUSTER_NAME} --for=condition=ControlPlaneReady --timeout=${TIMEOUT_IN_MINUTES}m; then
        echo "ERROR: Control plane failed to be ready"
        clusterctl describe cluster ${CLUSTER_NAME} --show-conditions=all
        exit 1
    fi
}

function wait_for_control_plane_nodes_healthy() {
    echo "### Waiting for control plane machines to become healthy"
    if ! kubectl wait machines --selector=cluster.x-k8s.io/control-plane-name=${CLUSTER_NAME}-control-plane --for=condition=NodeHealthy --timeout=${TIMEOUT_IN_MINUTES}m; then
        echo "ERROR: Control plane machines failed to become healthy"
        clusterctl describe cluster "${CLUSTER_NAME}" --show-conditions all
        exit 1
    fi
    echo "    Control plane machines healthy"
}

function wait_for_worker_nodes_ready() {
    echo "### Waiting for worker nodes to become ready"
    if ! kubectl wait machinedeployment "${CLUSTER_NAME}-md-0" --for=condition=Ready  --timeout=${TIMEOUT_IN_MINUTES}m; then
        echo "ERROR: Nodes failed to become ready"
        clusterctl describe cluster "${CLUSTER_NAME}" --show-conditions all
        kubectl describe machinedeployment "${CLUSTER_NAME}-md-0"
        exit 1
    fi
    if ! kubectl --kubeconfig=kubeconfig-${CLUSTER_NAME} wait nodes --all --all-namespaces --for=condition=Ready --timeout=30m; then
        echo "### Nodes are not ready"
        kubectl get nodes
        exit 1
    fi
    echo "    Worker nodes are ready"
}

function wait_for_pods_ready() {
    echo "### Waiting for pods to become ready"
    if ! kubectl --kubeconfig=kubeconfig-${CLUSTER_NAME} wait pods --all --all-namespaces --for=condition=Ready --timeout=${TIMEOUT_IN_MINUTES}m; then
        echo "ERROR: Pods failed to become ready"
        kubectl get pods --all-namespaces
        exit 1
    fi
    echo "    Pods are ready"
}

function move_capi_providers() {
    echo "### Initialize CAPH in workload cluster"
    clusterctl init \
        --kubeconfig=kubeconfig-${CLUSTER_NAME} \
        --infrastructure="${INFRASTRUCTURE_PROVIDER}" \
        --bootstrap="${BOOTSTRAP_PROVIDER}" \
        --control-plane="${CONTROL_PLANE_PROVIDER}" \
        --addon=helm \
        --wait-providers
    echo "### Waiting for management resources to be running"
    if ! kubectl --kubeconfig=kubeconfig-${CLUSTER_NAME} wait pods --all --all-namespaces --for=condition=Ready --timeout=30m; then
        echo "### Pods are not ready"
        kubectl get pods --all-namespaces
        exit 1
    fi
    echo "### Pods are ready"
    echo "### Move management resources to workload cluster"
    clusterctl move --to-kubeconfig=kubeconfig-${CLUSTER_NAME}
}

function fetch_capi_provider_logs() {
    echo "### Fetching logs"
    kubectl --kubeconfig=kubeconfig-demo get namespace --selector=cluster.x-k8s.io/provider --output=name \
    | cut -d/ -f2 \
    | while read -r NAMESPACE; do \
        kubectl --kubeconfig=kubeconfig-demo --namespace="${NAMESPACE}" get deployment --outout=name \
        | cut -d/ -f2 \
        | while read -r DEPLOYMENT; do \
            kubectl --kubeconfig=kubeconfig-demo --namespace="${NAMESPACE}" logs "deployment/${DEPLOYMENT}" >"${DEPLOYMENT}.log"
        done
    done
    if ! workload_logs "${CLUSTER_NAME}"; then
        echo "ERROR: Failed to fetch logs for workload provider"
        exit 1
    fi
}

function create_long_lived_admin_token() {
    echo "### Creating cluster admin"
    mv "kubeconfig-${CLUSTER_NAME}" "kubeconfig-${CLUSTER_NAME}-certificate"
    export KUBECONFIG="kubeconfig-${CLUSTER_NAME}-certificate"
    cat <<EOF | kubectl --namespace kube-system apply --filename=-
    apiVersion: v1
    kind: ServiceAccount
    metadata:
    name: my-cluster-admin
    namespace: kube-system
    EOF
    cat <<EOF | kubectl --namespace=kube-system apply --filename=-
    kind: ClusterRoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
    name: my-cluster-admin
    roleRef:
    kind: ClusterRole
    name: cluster-admin
    apiGroup: rbac.authorization.k8s.io
    subjects:
    - kind: ServiceAccount
    name: my-cluster-admin
    namespace: kube-system
    EOF
    cat <<EOF | kubectl --namespace=kube-system apply --filename=-
    apiVersion: v1
    kind: Secret
    metadata:
    name: my-cluster-admin-token
    annotations:
        kubernetes.io/service-account.name: my-cluster-admin
    type: kubernetes.io/service-account-token
    EOF
    TOKEN=$(
        kubectl --namespace=kube-system get secrets my-cluster-admin-token --output=json \
        | jq --raw-output '.data.token' \
        | base64 -d
    )
    SERVER=$(
        kubectl config view --raw --output json \
        | jq --raw-output '.clusters[].cluster.server'
    )
    CA=$(
        kubectl config view --raw --output json \
        | jq --raw-output '.clusters[].cluster."certificate-authority-data"' \
        | base64 -d
    )
    export KUBECONFIG="kubeconfig-${CLUSTER_NAME}"
    if test -f "${KUBECONFIG}"; then
        echo "kubeconfig ${KUBECONFIG} already exists" >&2
        exit 1
    fi
    touch "${KUBECONFIG}"
    kubectl config set-cluster default --server="${SERVER}" --certificate-authority=<(echo "${CA}") --embed-certs=true
    kubectl config set-credentials my-cluster-admin --token="${TOKEN}"
    kubectl config set-context cluster-admin --cluster=default --user=my-cluster-admin
    kubectl config use-context cluster-admin
}

function bootstrap_patch_coredns() {
    NAMESERVERS="$(
        grep nameserver /etc/resolv.conf \
        | cut -d' ' -f2 \
        | xargs echo
    )"

    # TODO: Get Corefile and patch nameservers
    COREFILE="$(
        kubectl --namespace=kube-system get configmap coredns --output=json \
        | jq --raw-output ".data.Corefile"
    )"
    #cat Corefile.patch.yaml.envsubst \
    #| NAMESERVERS="${NAMESERVERS}" envsubst '$NAMESERVERS' \
    #>Corefile.patch.yaml
    #if ! test -f Corefile.patch.yaml || ! test -s Corefile.patch.yaml; then
    #    echo "ERROR: Error envsubsting Corefile.patch.yaml"
    #    return 1
    #fi
    
    # TODO: Patch CoreDNS ConfigMap
    #KUBECONFIG="kubeconfig-bootstrap" kubectl patch configmap coredns \
    #    --kubeconfig=kubeconfig-bootstrap \
    #    --namespace=kube-system \
    #    --patch-file=Corefile.patch.yaml

    # TODO: Add custom domain with DNS servers
    # grp.haufemg.com:53 {
    #     errors
    #     cache 30
    #     forward . 10.11.11.11
    # }
}
