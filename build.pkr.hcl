build {
  name    = "wazuh-stack-ubuntu2404"
  sources = ["source.proxmox-iso.wazuh_stack"]

  provisioner "file" {
    source      = "${path.root}/scripts/"
    destination = "/tmp/wazuh-scripts"
  }

  provisioner "shell" {
    script = "/tmp/wazuh-scripts/provision-wazuh-manager.sh"
    execute_command = "cd /tmp/wazuh-scripts; chmod +x provision-wazuh-manager.sh; sudo -n -E bash provision-wazuh-manager.sh"
  }
}
