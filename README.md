# capictl

This repository contains an opinionated script to create a Kubernetes cluster using the [Cluster API](https://cluster-api.sigs.k8s.io/) on a few infrastructure providers.

🎉 **This is the successor of [`k8s-caph-talos`](https://github.com/nicholasdille/k8s-caph-talos).** 🎉

After creating a local bootstrap cluster, the workload cluster is created. At the end of the rollout, the management services are moved into the workload cluster.

The resulting cluster will be able to manage itself as well as create new clusters.

## Supported infrastructure

Bootstrap clusters: [kind](https://kind.sigs.k8s.io/), [k3d](https://k3d.io)

Infrastructure providers: docker, hetzner, vsphere

CNI: [cilium](https://cilium.io/)

## Usage

`capictl` supports a number of options to configure the cluster. The following command will create a cluster with the default configuration:

```shell
bash capictl -n my-cluster
```

The following settings are supported:

| Option | Variable | Default | Description |
|--------|----------|---------|-------------|
| `-n` | `CLUSTER_NAME` | | The name of the cluster |
| `-v` | `KUBERNETES_VERSION` | (latest) | The version of Kubernetes to deploy |
| `-b` | `BOOTSTRAP_CLUSTER_PROVIDER` | `kind` | The provider for the bootstrap cluster (valid values are `kind`, `k3d`) |
| `-i` | `WORKLOAD_PROVIDER` | `docker` | The provider for the workload cluster (valid values are `docker`, `hetzner`, `vsphere`) |
| `-p` | `CNI_PLUGIN` | `cilium` | The CNI plugin to use (valid values are `cilium`) |
| `-x` | `POD_CIDR` | `10.42.128.0/17` | The CIDR for pods |
| `-y` | `SERVICE_CIDR` | `10.42.0.0/17` | The CIDR for services |
| `-c` | `CONTROL_PLANE_NODE_COUNT` | `1` | The number of control plane nodes |
| `-w` | `WORKER_NODE_COUNT` | `2` | The number of worker nodes |

All variables can be configured through a `.env` file as well (including the provider specific variables described below).

The corresponding `kubeconfig` file is stored in the current directory as `kubeconfig-${CLUSTER_NAME}`.

The following provider specific variables are supported:

### Hetzner

See the [Hetzner Cloud provider documentation](https://github.com/syself/cluster-api-provider-hetzner/blob/main/docs/topics/preparation.md#variable-preparation-to-generate-a-cluster-template).

The following default values are configured:

| Variable                            | Default | Description                                  |
|-------------------------------------|---------|----------------------------------------------|
| `HCLOUD_REGION`                     | `fsn1`  | The Hetzner Cloud region                     |
| `HCLOUD_CONTROL_PLANE_MACHINE_TYPE` | `cx22`  | The Hetzner Cloud control plane machine type |
| `HCLOUD_WORKER_MACHINE_TYPE`        | `cx22`  | The Hetzner Cloud worker machine type        |

### vsphere

See the [vsphere provider documentation](https://github.com/kubernetes-sigs/cluster-api-provider-vsphere/blob/main/docs/getting_started.md#configuring-and-installing-cluster-api-provider-vsphere-in-a-management-cluster).

## Prerequisites

The script relies on a number of binaries to work:
- `docker`
- `envsubst`
- `jq`
- `kind` or `k3d`
- `kubectl`
- `hcloud`
- `clusterctl`
- `cilium`

Those prerequisites can be installed with [`uniget`](https://uniget.dev).

## Image

This repository contains Packer based images for Hetzner Cloud located in the [`images` directory](images/).

## Internals

This is how the script works:

1. Create a bootstrap cluster using `kind` or `k3d`
1. Initialize Cluster API in the bootstrap cluster
1. Generate a cluster configuration for the workload cluster
1. Wait for the control plane to initialize
1. Deploy Cilium
1. Deploy necessary components, e.g. cloud controller manager and CSI
1. Wait for the controle plane to be ready
1. Wait for the worker nodes to be ready
1. Initialize Cluster API in the workload cluster
1. Move the cluster configuration to the workload cluster
1. Create a `kubeconfig` for the workload cluster with a dedicated service account

## TODO

- [ ] Talos
- [x] Idempotency (being able to restart and pick up where it left off)
- [x] Configure CIDRs for pods and services
- [x] Test `kubectl wait`
- [x] Support infrastructure docker?
- [x] Support infrastructure vcluster?
- [ ] Check out [Cluster API Operator](https://github.com/kubernetes-sigs/cluster-api-operator)
