function cni_precheck() {
    if ! type helm >/dev/null 2>&1; then
        echo "ERROR: helm not found"
        return 1
    fi
    if ! type cilium >/dev/null 2>&1; then
        echo "ERROR: cilium not found"
        return 1
    fi
}

function cni_deploy() {
    local name=$1

    helm repo add cilium https://helm.cilium.io
    helm repo update cilium
    KUBECONFIG=kubeconfig-${name} \
    helm upgrade --install \
        --namespace kube-system \
        cilium cilium/cilium \
            --set cluster.id=0 \
            --set cluster.name=${name} \
            --set encryption.nodeEncryption=false \
            --set extraConfig.ipam=kubernetes \
            --set extraConfig.kubeProxyReplacement=strict \
            --set kubeProxyReplacement=strict \
            --set operator.replicas=1 \
            --set serviceAccounts.cilium.name=cilium \
            --set serviceAccounts.operator.name=cilium-operator \
            --set tunnel=vxlan \
            --set prometheus.enabled=true \
            --set operator.prometheus.enabled=true \
            --set hubble.relay.enabled=true \
            --set hubble.ui.enabled=true \
            --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}" \
            --wait \
            --timeout 5m
}

function cni_post_install_hook() {
    local name=$1

    KUBECONFIG=kubeconfig-${name} \
    cilium status \
        --wait \
        --wait-duration 5m
}