# ===== Identity =====
variable "template_prefix" {
  type    = string
  default = "tpl"
}

variable "hostname" {
  type    = string
  default = "wazuh-stack"
}

# ===== VM sizing =====
variable "cpu_cores" {
  type    = number
  default = 4
}

variable "memory_mb" {
  type    = number
  default = 8192
}

variable "disk_storage_pool" {
  type    = string
  default = "hdd-lvm"
}

variable "disk_size" {
  type    = string
  default = "40G"
}

# ===== Storage / Network =====
variable "iso_storage_pool" {
  type    = string
  default = "hdd-data"
}

variable "iso_file" {
  type    = string
  default = "ubuntu-24.04.3-live-server-amd64.iso"
}

variable "mgmt_bridge" {
  type    = string
  default = env("PACKER_INTERNET_BRIDGE_CARD")
}

variable "cloud_init_storage_pool" {
  type    = string
  default = "local-lvm"
}

# ===== SSH key-based =====
variable "ssh_username" {
  type    = string
  default = "root"
}

variable "pri_key" {
  type    = string
  default     = env("PACKER_SSH_PRIVATE_KEY")
}

variable "pub_key" {
  type    = string
  default     = env("PACKER_SSH_PUBLIC_KEY")
}

variable "vm_interface" {
  type    = string
  default = "ens18"
}

# ===== Proxmox connection =====
variable "proxmox_url" {
  type = string
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type = string
}

variable "proxmox_node" {
  type = string
}

variable "proxmox_insecure_skip_tls_verify" {
  type    = bool
  default = true
}

# NOTE: 0 is what you provided; behavior depends on plugin implementation.
variable "vm_id" {
  type    = number
  default = 0
}

# Autoinstall requires a non-root user + password hash (SSH password login is disabled).
variable "ubuntu_password_hash" {
  type = string
}
