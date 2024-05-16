# capictl

This repository contains an opinionated script to create a Kubernetes cluster using the [Cluster API](https://cluster-api.sigs.k8s.io/) on a few infrastructure providers.

After creating a local bootstrap cluster, the workload cluster is created. At the end of the rollout, the management services are moved into the workload cluster.

The resulting cluster will be able to manage itself as well as create new clusters.

## Supported infrastructure

Bootstrap clusters: kind, k3d

Infrastructure providers: docker, hetzner, vsphere

CNI: cilium

## Usage

Calling the following script ...

```shell
bash capictl
```

...creates a Kubernetes cluster using the Cluster API.

The corresponding `kubeconfig` file is stored in the current directory as `kubeconfig-${CLUSTER_NAME}`.

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

## Configuration

Call `capictl --help`

## Internals

This is how the script works:

1. Create a bootstrap cluster using `kind` or `k3d`
1. Initialize Cluster API for Hetzner Cloud in the bootstrap cluster
1. Generate a cluster configuration for the workload cluster
1. Wait for the control plane to initialize
1. Deploy Cilium
1. Deploy cloud-controller-manager for Hetzner Cloud
1. Deploy the Hetzner Cloud CSI driver
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
