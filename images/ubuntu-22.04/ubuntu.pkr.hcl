packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1"
    }
  }
}

variable "os" {
    type = string
    default = "ubuntu-22.04"
}

variable "arch" {
    type = string
    default = "amd64"
}

variable "kubernetes_version" {
  type    = string
  # renovate: datasource=github-releases depName=kubernetes/kubernetes extractVersion=^v(?<version>\d+\.\d+\.\d+)$
  default = "1.32.2"
}

variable "containerd_version" {
  type    = string
  # renovate: datasource=github-releases depName=containerd/containerd extractVersion=^v(?<version>\d+\.\d+\.\d+)$
  default = "1.7.18"
}

variable "cni_version" {
  type    = string
  # renovate: datasource=github-releases depName=containernetworking/plugins extractVersion=^v(?<version>\d+\.\d+\.\d+)$
  default = "1.5.1"
}

variable "image-name" {
    type = string
    default = "ubuntu-22.04-kubeadm"
}

variable "version" {
    type = string
    default = "{{isotime '2006-01-02-1504'}}"
}

source "hcloud" "ubuntu" {
    image = "${var.os}"
    location = "fsn1"
    server_type = "cx21"
    ssh_username = "root"

    snapshot_name = "${var.os}-${var.arch}-k8s-${var.kubernetes_version}"
    snapshot_labels = {
        "os" = "${var.os}"
        "arch" = "${var.arch}"
        "kubernetes" = "${var.kubernetes_version}"
        "containerd" = "${var.containerd_version}"
        "cni" = "${var.cni_version}"
        "caph-image-name" = "${var.os}-${var.arch}-k8s-${var.kubernetes_version}"
    }
}

build {
    sources = ["source.hcloud.ubuntu"]

    provisioner "shell" {
        environment_vars = [
            "PACKER_OS_IMAGE=${var.os}",
            "PACKER_ARCH=${var.arch}",
            "KUBERNETES_VERSION=${var.kubernetes_version}",
            "CONTAINERD=${var.containerd_version}",
            "CNI=${var.cni_version}",
        ]
        scripts = [
            "scripts/base.sh",
            "scripts/cilium-requirements.sh",
            "scripts/cri.sh",
            "scripts/kubernetes.sh",
            "scripts/cleanup.sh"
        ]
    }
}