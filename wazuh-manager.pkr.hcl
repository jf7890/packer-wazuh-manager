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

# ==========================================================
# Proxmox Builder: Ubuntu 24.04 + Wazuh all-in-one stack
# - net0: mgmt (vmbr10) used ONLY for Packer provisioning
# - net1: blue (blue)  kept for the final template
# ==========================================================
source "proxmox-iso" "wazuh_stack" {
  # ===== Proxmox connection =====
  proxmox_url      = var.proxmox_url
  username         = var.proxmox_username
  token            = var.proxmox_token
  node             = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify

  # NOTE: var.vm_id default = 0 (auto). If your plugin treats 0 as "set", change to a real ID.
  vm_id = var.vm_id

  # ===== Template identity =====
  vm_name              = local.template_name
  template_name        = local.template_name
  template_description = "Ubuntu 24.04 + Wazuh all-in-one. Build uses net0(mgmt) then post-step keeps only blue NIC."

  # ===== VM sizing =====
  cores  = var.cpu_cores
  memory = var.memory_mb

  # ===== Boot ISO (already uploaded to Proxmox storage) =====
  boot_iso {
    iso_file  = "${var.iso_storage_pool}:iso/${var.iso_file}"
    unmount   = true
  }

  # ===== Disk =====
  scsi_controller = "virtio-scsi-pci"
  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.disk_storage_pool
    format       = "raw"
  }

  # net0: mgmt
  network_adapters {
    model  = "virtio"
    bridge = var.mgmt_bridge
    vlan_tag = 99
  }

  # ===== Autoinstall seed served by Packer HTTP server =====
  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data.tpl", {
      hostname             = var.hostname
      pub_key       = var.pub_key
      ubuntu_password_hash = var.ubuntu_password_hash
    })
    "/meta-data" = templatefile("${path.root}/http/meta-data.tpl", {
      hostname = var.hostname
    })
  }

  # ===== QEMU guest agent for IP discovery =====
  qemu_agent = true

  # ===== SSH (key-based, root) =====
  ssh_username         = var.ssh_username
  ssh_private_key_file = var.pri_key
  ssh_timeout          = "60m"

  # plugin reads the IP address for this interface from qemu-guest-agent
  vm_interface         = var.vm_interface

  # ===== Ubuntu autoinstall boot command =====
  # This sequence is often the flakiest part and may need small adjustments.
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end><wait>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ cloud-config-url=/dev/null net.ifnames=0 biosdevname=0 ---<wait>",
    "<f10><wait>"
  ]

  # ===== Proxmox Cloud-Init drive (kept for clones; optional) =====
  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool
}

build {
  name    = "wazuh-stack-ubuntu2404"
  sources = ["source.proxmox-iso.wazuh_stack"]

  provisioner "shell" {
    script = "${path.root}/scripts/provision-wazuh-manager.sh"
    execute_command = "chmod +x {{ .Path }}; sudo -n -E bash '{{ .Path }}'"
  }
}
