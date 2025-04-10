function bootstrap_precheck() {
    if ! type hcloud >/dev/null 2>&1; then
        echo "ERROR: hcloud not found"
        return 1
    fi

    if test -z "${HCLOUD_TOKEN}"; then
        echo "ERROR: Missing HCLOUD_TOKEN. Aborting."
        exit 1
    fi
    export HCLOUD_TOKEN

    if ! test -f ssh-jump; then
        ssh-keygen -f ssh-jump -t ed25519 -N ''
        chmod 0600 ssh-jump
    fi

    # TODO: Check for existence
    hcloud ssh-key create \
        --name="${CLUSTER_NAME}-jump" \
        --public-key-from-file=./ssh-jump.pub \
        --label=type="${CLUSTER_NAME}-jump"
    # TODO: Check for existence
    hcloud server create \
        --name="${CLUSTER_NAME}-jump" \
        --type=cx32 \
        --image=ubuntu-24.04 \
        --ssh-key="${CLUSTER_NAME}-jump" \
        --label=type="${CLUSTER_NAME}-jump"

    JUMP_IP="$(
        hcloud server list --selector=type="${CLUSTER_NAME}-jump" --output=json \
        | jq -r '.[].public_net.ipv4.ip'
    )"
    cat >"${HOME}/.ssh/config.d/${CLUSTER_NAME}-jump" <<-EOF
        Host ${CLUSTER_NAME}-jump
            Hostname "${JUMP_IP}"
            User root
            IdentityFile ${PWD}/ssh-jump
            StrictHostKeyChecking no
            UserKnownHostsFile /dev/null
            LogLevel ERROR
	EOF

    SECONDS=0
    while ! ssh "${CLUSTER_NAME}-jump" true; do
        if [ "${SECONDS}" -gt 120 ]; then
            echo "ERROR: Timeout waiting for SSH connection to ${CLUSTER_NAME}-jump."
            exit 1
        fi
        sleep 5
    done

    if ! ssh "${CLUSTER_NAME}-jump" docker version >/dev/null 2>&1; then
        ssh "${CLUSTER_NAME}-jump" bash <<-EOF
            curl -sLf https://github.com/uniget-org/cli/releases/latest/download/uniget_Linux_$(uname -m).tar.gz \
            | tar -xzC /usr/local/bin uniget

            uniget install docker kind kubectl helm clusterctl jq yq
            groupadd docker
            systemctl daemon-reload
            systemctl disable docker.service
            systemctl enable docker.socket
            systemctl start docker.socket
            docker version
		EOF
    fi

    if ! ssh "${CLUSTER_NAME}-jump" type kind >/dev/null 2>&1; then
        echo "ERROR: kind not found. Required by bootstrap provider."
        return 1
    fi
}

function bootstrap_exists() {
    local name=$1

    ssh "${CLUSTER_NAME}-jump" \
        kind get clusters \
    | grep -q "${name}"
}

function bootstrap_create() {
    local name=$1

    if bootstrap_exists "${name}"; then
        echo "### Bootstrap cluster already exists"

    else
        echo "### Creaking bootstrap cluster"
        cat bootstrap/kind.yaml \
        | ssh "${CLUSTER_NAME}-jump" \
            kind create cluster \
                --name="${name}" \
                --config=- \
                --wait=5m
    fi
}

function bootstrap_delete() {
    local name=$1
    
    if bootstrap_exists "${name}"; then
        echo "### Deleting bootstrap cluster"
        ssh "${CLUSTER_NAME}-jump" \
            kind delete cluster --name "${name}"

        rm -f ~/.ssh/config.d/"${CLUSTER_NAME}-jump"
        hcloud server delete "${CLUSTER_NAME}-jump"
        hcloud ssh-key delete "${CLUSTER_NAME}-jump"
    fi

    if test -z "${VM_KIND_TUNNEL_PID}"; then
        PORT="$(
            kubectl --kubeconfig=./kubeconfig-bootstrap config view --output=json \
            | jq --raw-output --arg name "${name}" '.clusters[] | select(.name == "kind-\($name)") | .cluster.server' \
            | cut -d: -f3
        )"
        VM_KIND_TUNNEL_PID="$(
            netstat -tunapl 2>/dev/null \
            | grep LISTEN \
            | grep "127.0.0.1:${POST}" \
            | tr -s " " \
            | cut -d' ' -f7 \
            | cut -d/ -f1
        )"
    fi
    if test -n "${VM_KIND_TUNNEL_PID}"; then
        echo "### Killing tunnel process"
        kill "${VM_KIND_TUNNEL_PID}"
    fi
}

function bootstrap_kubeconfig() {
    local name=$1

    if bootstrap_exists "${name}"; then
        ssh "${CLUSTER_NAME}-jump" \
            kind get kubeconfig --name "${name}" \
        >kubeconfig-bootstrap
    fi

    PORT="$(
        kubectl --kubeconfig=./kubeconfig-bootstrap config view --output=json \
        | jq --raw-output --arg name "${name}" '.clusters[] | select(.name == "kind-\($name)") | .cluster.server' \
        | cut -d: -f3
    )"
    if ! netstat -tunal | grep LISTEN | grep -q 127.0.0.1:"${PORT}"; then
        VM_KIND_TUNNEL_PID="$(
            sh -c "echo \$\$ && exec ssh -fNL ${PORT}:localhost:${PORT} ${CLUSTER_NAME}-jump" \
            | head -n 1
        )"
    fi
}

function bootstrap_post_create_hook() {
    true
}

function bootstrap_post_init_hook() {
    true
}