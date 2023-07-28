# clusterctlctl

## docker

1. export CLUSTER_TOPOLOGY=true
2. clusterctl init --infrastructure docker

## capa

1. Install clusterawsadm
2. Credentials:
  ```bash
  export AWS_REGION=us-east-1 # This is used to help encode your environment variables
  export AWS_ACCESS_KEY_ID=<your-access-key>
  export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
  export AWS_SESSION_TOKEN=<session-token> # If you are using Multi-Factor Auth.
  ```
3. clusterawsadm bootstrap iam create-cloudformation-stack
4. export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
5. clusterctl init --infrastructure aws

## capv

1. export VSPHERE_USERNAME="vi-admin@vsphere.local"
2. export VSPHERE_PASSWORD="admin!23"
3. `~/.cluster-api/clusterctl.yaml` (https://github.com/kubernetes-sigs/cluster-api-provider-vsphere/blob/main/docs/getting_started.md#configuring-and-installing-cluster-api-provider-vsphere-in-a-management-cluster)
  ```bash
  ## -- Controller settings -- ##
    VSPHERE_USERNAME: "vi-admin@vsphere.local"                    # The username used to access the remote vSphere endpoint
    VSPHERE_PASSWORD: "admin!23"                                  # The password used to access the remote vSphere endpoint

    ## -- Required workload cluster default settings -- ##
    VSPHERE_SERVER: "10.0.0.1"                                    # The vCenter server IP or FQDN
    VSPHERE_DATACENTER: "SDDC-Datacenter"                         # The vSphere datacenter to deploy the management cluster on
    VSPHERE_DATASTORE: "DefaultDatastore"                         # The vSphere datastore to deploy the management cluster on
    VSPHERE_NETWORK: "VM Network"                                 # The VM network to deploy the management cluster on
    VSPHERE_RESOURCE_POOL: "*/Resources"                          # The vSphere resource pool for your VMs
    VSPHERE_FOLDER: "vm"                                          # The VM folder for your VMs. Set to "" to use the root vSphere folder
    VSPHERE_TEMPLATE: "ubuntu-1804-kube-v1.17.3"                  # The VM template to use for your management cluster.
    CONTROL_PLANE_ENDPOINT_IP: "192.168.9.230"                    # the IP that kube-vip is going to use as a control plane endpoint
    VIP_NETWORK_INTERFACE: "ens192"                               # The interface that kube-vip should apply the IP to. Omit to tell kube-vip to autodetect the interface.
    VSPHERE_TLS_THUMBPRINT: "..."                                 # sha1 thumbprint of the vcenter certificate: openssl x509 -sha1 -fingerprint -in ca.crt -noout
    EXP_CLUSTER_RESOURCE_SET: "true"                              # This enables the ClusterResourceSet feature that we are using to deploy CSI
  VSPHERE_SSH_AUTHORIZED_KEY: "ssh-rsa AAAAB3N..."              # The public ssh authorized key on all machines in this cluster.
                                                                #  Set to "" if you don't want to enable SSH, or are using another solution.
  VSPHERE_STORAGE_POLICY: ""                                    # This is the vSphere storage policy. Set it to "" if you don't want to use a storage policy.
  "CPI_IMAGE_K8S_VERSION": "v1.25.0"                            # The version of the vSphere CPI image to be used by the CPI workloads
                                                                #  Keep this close to the minimum Kubernetes version of the cluster being created.
  ```
5. clusterctl init --infrastructure vsphere

## caph

1. https://github.com/syself/cluster-api-provider-hetzner
2. `~/.cluster-api/clusterctl.yaml` (https://github.com/syself/cluster-api-provider-hetzner/blob/main/docs/topics/preparation.md#variable-preparation-to-generate-a-cluster-template)
  ```bash
  export HCLOUD_SSH_KEY="<ssh-key-name>" \
  export CLUSTER_NAME="my-cluster" \
  export HCLOUD_REGION="fsn1" \
  export CONTROL_PLANE_MACHINE_COUNT=3 \
  export WORKER_MACHINE_COUNT=3 \
  export KUBERNETES_VERSION=1.25.2 \
  export HCLOUD_CONTROL_PLANE_MACHINE_TYPE=cpx31 \
  export HCLOUD_WORKER_MACHINE_TYPE=cpx31
  ```
3. clusterctl init --core cluster-api --bootstrap kubeadm --control-plane kubeadm --infrastructure hetzner
