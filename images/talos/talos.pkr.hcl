packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1"
    }
  }
}

variable "talos_version" {
  type    = string
  # renovate: datasource=github-releases depName=siderolabs/talos extractVersion=^v(?<version>\d+\.\d+\.\d+)$
  default = "1.9.4"
}

variable "arch" {
  type    = string
  default = "amd64"
}

variable "server_type" {
  type    = string
  default = "cx21"
}

variable "server_location" {
  type    = string
  default = "hel1"
}

locals {
  image = "https://github.com/siderolabs/talos/releases/download/v${var.talos_version}/hcloud-${var.arch}.raw.xz"
}

source "hcloud" "talos" {
  rescue       = "linux64"
  image        = "debian-11"
  location     = "${var.server_location}"
  server_type  = "${var.server_type}"
  ssh_username = "root"

  snapshot_name   = "talos-${var.talos_version}"
  snapshot_labels = {
    type    = "infra",
    os      = "talos",
    version = "${var.talos_version}",
    arch    = "${var.arch}",
    "caph-image-name" = "talos-${var.talos_version}",
  }
}

build {
  sources = ["source.hcloud.talos"]

  provisioner "shell" {
    inline = [
      "apt-get install -y wget",
      "wget -O /tmp/talos.raw.xz ${local.image}",
      "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync",
    ]
  }
}
