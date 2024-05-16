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
