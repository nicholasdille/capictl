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
    helm upgrade --install --namespace=kube-system \
        cilium cilium/cilium \
            --set cluster.id=0 \
            --set cluster.name=${name} \
            --set encryption.nodeEncryption="false" \
            --set envoy.enabled="false" \
            --set ipam.mode=kubernetes \
            --set kubeProxyReplacement="true" \
            --set operator.replicas=1 \
            --set serviceAccounts.cilium.name=cilium \
            --set serviceAccounts.operator.name=cilium-operator \
            --set tunnel-protocol=vxlan \
            --set prometheus.enabled="true" \
            --set operator.prometheus.enabled="true" \
            --set hostFirewall.enabled="false" \
            --set podSecurityContext.appArmorProfile.type="Unconfined" \
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