# ===== VM sizing =====
cpu_cores = 4
memory_mb = 8192
disk_storage_pool = "hdd-lvm"
disk_size         = "40G"

# ===== Storage / Network =====
iso_storage_pool        = "hdd-data"
blue_bridge             = "blue"
cloud_init_storage_pool = "local-lvm"

# ===== SSH key-based =====
ssh_username         = "root"
vm_interface         = "ens18"

# ===== Proxmox connection =====
proxmox_url      = "https://10.10.100.1:8006/api2/json"
proxmox_username = "root@pam!packer"
proxmox_token    = "28786dd2-1eed-44e6-b8a4-dc2221ce384d"
proxmox_node     = "homelab"
proxmox_insecure_skip_tls_verify = true
vm_id = 0

# Autoinstall identity password hash ("ubuntu"); SSH password login is disabled.
ubuntu_password_hash = "$6$m8O6FGBgaHES4080$9WtL65yUXIaxWpbQv3p6ZENgVTK2UUTsp9exPikZg6OfSQPTSwvXeGK0w8IvfZQa9Ov6wfpBp9SskhYY7msfC."
