build {
  name    = "wazuh-stack-ubuntu2404"
  sources = ["source.proxmox-iso.wazuh_stack"]

  provisioner "file" {
    source      = "${path.root}/scripts/"
    destination = "/tmp/wazuh-scripts"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/wazuh-scripts/provision-wazuh-manager.sh",
      "cd /tmp/wazuh-scripts && sudo -n -E bash ./provision-wazuh-manager.sh"
    ]
  }
}
