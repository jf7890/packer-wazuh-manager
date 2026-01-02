packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.0"
    }
  }
}

locals {
  template_name = "${var.template_prefix}-${var.hostname}"
}

source "proxmox-iso" "wazuh_manager" {
  # =========================
  # Proxmox connection
  # =========================
  proxmox_url              = var.proxmox_url
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node

  vm_id   = var.vm_id
  vm_name = local.template_name

  template_name        = local.template_name
  template_description = "Wazuh Manager on Ubuntu 24.04 (non-docker, key-only SSH)."
  tags                 = "ubuntu;wazuh;manager;template"

  # =========================
  # Boot ISO
  # =========================
  boot_iso {
    type             = "scsi"
    iso_url          = "https://download.nus.edu.sg/mirror/ubuntu-releases/releases/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
    iso_checksum     = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
    iso_storage_pool = var.iso_storage_pool
    iso_download_pve = true
    unmount          = true
  }

  # =========================
  # VM hardware
  # =========================
  cores           = var.cpu_cores
  sockets         = 1
  cpu_type        = "host"
  memory          = var.memory_mb
  os              = "l26"
  bios            = "seabios"
  scsi_controller = "virtio-scsi-single"
  qemu_agent      = true

  # Packer lấy IP từ NIC nào
  vm_interface = var.vm_interface

  # =========================
  # Disk (đúng syntax như blueteam-router)
  # =========================
  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.disk_storage_pool
    format       = "raw"
    cache_mode   = "none"
    io_thread    = true
    discard      = true
  }

  # =========================
  # Network adapters
  # =========================
  network_adapters {
    model  = "virtio"
    bridge = var.mgmt_bridge
  }

  # =========================
  # Packer HTTP server (serves ./http)
  # =========================
  http_directory = "${path.root}/http"

  # =========================
  # Boot & unattended install (Ubuntu autoinstall)
  # =========================
  boot_wait = "8s"

  # NOTE: Boot command may need slight adjustment depending on the ISO/GRUB screen on your console.
  # This is a common pattern for Ubuntu live-server autoinstall.
boot_command = [
  "<esc><wait>",
  "e<wait>",

  # Trong GRUB editor: xuống đúng dòng bắt đầu bằng "linux ..."
  "<down><end><wait>",

  # Append kernel params (nhớ có trailing slash và '---')
  " autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ip=dhcp ipv6.disable=1 ---<wait>",

  "<f10><wait>"
]

  # =========================
  # SSH communicator
  # =========================
  communicator         = "ssh"
  ssh_username         = var.ssh_username
  ssh_port             = 22
  ssh_timeout          = var.ssh_timeout
  ssh_private_key_file = pathexpand(var.ssh_private_key_file)

  # =========================
  # Cloud-init CDROM after convert template
  # =========================
  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool
}

build {
  sources = ["source.proxmox-iso.wazuh_manager"]

  provisioner "shell" {
    script = "scripts/provision-wazuh-manager.sh"
  }
}
