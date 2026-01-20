build {
  name    = "wazuh-stack-ubuntu2404"
  sources = ["source.proxmox-iso.wazuh_stack"]

  provisioner "shell" {
    script = "${path.root}/scripts/provision-wazuh-manager.sh"
    execute_command = "chmod +x {{ .Path }}; sudo -n -E bash '{{ .Path }}'"
  }
}