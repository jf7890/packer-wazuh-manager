variable "template_prefix" {
  type        = string
  default     = "tpl"
  description = "Prefix tên template."
}

variable "hostname" {
  type        = string
  default     = "wazuh-manager"
  description = "Hostname (cũng dùng để ghép tên template)."
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL, e.g. https://pve:8006/api2/json"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox username incl. realm. For token auth: user@realm!tokenid"
}

variable "proxmox_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret (NOT the token id)."
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name to build on."
}

variable "proxmox_insecure_skip_tls_verify" {
  type        = bool
  default     = true
  description = "Skip TLS verify for Proxmox API."
}

variable "vm_id" {
  type        = number
  default     = 0
  description = "Optional fixed VMID. Set 0 to auto-assign."
}

# =========================
# VM sizing (default theo yêu cầu)
# =========================
variable "cpu_cores" {
  type        = number
  default     = 4
  description = "Number of vCPU cores."
}

variable "memory_mb" {
  type        = number
  default     = 8192
  description = "Memory in MB."
}

variable "disk_storage_pool" {
  type        = string
  default     = "hdd-lvm"
  description = "Proxmox storage pool for the VM disk (e.g. local-lvm, hdd-lvm)."
}

variable "disk_size" {
  type        = string
  default     = "40G"
  description = "VM disk size, e.g. 40G."
}

# =========================
# Portable options
# =========================
variable "iso_storage_pool" {
  type        = string
  description = "Proxmox storage pool to store the downloaded ISO (e.g. hdd-data)."
}

variable "mgmt_bridge" {
  type        = string
  description = "Proxmox bridge for management/WAN NIC (net0)."
}

variable "cloud_init_storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool to store the Cloud-Init CDROM."
}

# =========================
# SSH communicator (key-based)
# =========================
variable "ssh_username" {
  type        = string
  default     = "blue"
  description = "SSH username to connect after install."
}

variable "ssh_private_key_file" {
  type        = string
  description = "Private key path that matches the authorized key injected by autoinstall."
}

variable "ssh_timeout" {
  type        = string
  default     = "45m"
  description = "SSH timeout for long installs."
}

# Optional: interface name inside guest to help plugin pick IP (can override if needed)
variable "vm_interface" {
  type        = string
  default     = "eth0"
  description = "Guest NIC name used to detect IP (adjust if your guest uses a different name)."
}
