packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:a6d9b9cbed35b56b73db57c7f0f7ca5d11cbdd13b8a2b94af9cd10eeef1a2e16"
}

variable "disk_size" {
  type    = string
  default = "20G"
}

variable "memory" {
  type    = number
  default = 4096
}

variable "cpus" {
  type    = number
  default = 2
}

source "qemu" "claude-sandbox" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  output_directory = "output/claude-sandbox"
  vm_name          = "claude-sandbox.qcow2"
  format           = "qcow2"
  disk_size        = var.disk_size
  memory           = var.memory
  cpus             = var.cpus
  accelerator      = "kvm"
  headless         = true

  http_directory = "http"

  boot_command = [
    "<wait>c<wait>",
    "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/ ---<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]
  boot_wait = "5s"

  ssh_username     = "sandbox"
  ssh_password     = "sandbox"
  ssh_timeout      = "45m"
  shutdown_command = "echo 'sandbox' | sudo -S shutdown -P now"

  qemuargs = [
    ["-display", "none"],
    ["-cpu", "host"]
  ]
}

build {
  sources = ["source.qemu.claude-sandbox"]

  provisioner "shell" {
    inline = ["mkdir -p /tmp/sandbox-files"]
  }

  provisioner "file" {
    source      = "../../tmux.conf"
    destination = "/tmp/sandbox-files/tmux.conf"
  }

  provisioner "file" {
    source      = "../../.p10k.zsh"
    destination = "/tmp/sandbox-files/.p10k.zsh"
  }

  provisioner "shell" {
    script = "provision.sh"
  }
}
