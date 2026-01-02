# ===== Proxmox connection =====
proxmox_url      = "https://10.10.100.1:8006/api2/json"
proxmox_username = "root@pam!packer"
proxmox_token    = "28786dd2-1eed-44e6-b8a4-dc2221ce384d"
proxmox_node     = "homelab"
proxmox_insecure_skip_tls_verify = true
vm_id = 0

# ===== Template naming =====
template_prefix = "tpl"
hostname        = "wazuh-manager"

# ===== VM sizing (default: 4c/8g/40g) =====
cpu_cores = 4
memory_mb = 8192
disk_storage_pool = "hdd-lvm"
disk_size         = "40G"

# ===== Storage / Network =====
iso_storage_pool        = "hdd-data"
mgmt_bridge             = "blue"
cloud_init_storage_pool = "local-lvm"

# ===== SSH key-based =====
ssh_username         = "blue"
ssh_private_key_file = "~/.ssh/id_ed25519"
vm_interface         = "eth0"
