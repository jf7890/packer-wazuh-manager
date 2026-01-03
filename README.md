# Wazuh Manager Template (Packer + Proxmox)

This folder builds **only** the Wazuh Manager template (Ubuntu 24.04) on Proxmox using Packer.

## Why Ubuntu (not Alpine)
Wazuh's official installation guide lists supported OS for Wazuh server and includes **Ubuntu 24.04**.
Alpine is not listed as a supported OS for Wazuh server packages.

## What gets installed
- wazuh-manager
- filebeat (installed but **disabled** by default)
- Custom `ossec.conf` and `local_rules.xml` from your provided prompt doc

A cert placeholder is created:
- `/etc/filebeat/certs/EMPTY_CERT.pem`
And a note file:
- `/root/WAZUH_CERTS_NOTE.txt`

## SSH access
- User: `blue`
- SSH password login: disabled
- Authorized key: your provided public key is embedded in the autoinstall.

Packer communicator requires you to provide **ssh_private_key_file** in your `.auto.pkrvars.hcl`.

## Proxmox auth
- Provide either password or API token.

    - If you use API tokens: set `proxmox_username` like `user@pam!tokenid` and set `proxmox_token` to the token secret.


## Disk layout
This template is **LVM-only** (Ubuntu autoinstall storage layout: `lvm`).

Khi có Indexer thì “đúng bài” bạn nên làm trong script

Ghi /etc/filebeat/filebeat.yml trỏ tới indexer

Copy cert thật vào /etc/filebeat/certs/

rồi mới enable --now filebeat


## Usage
```bash
cd wazuh-manager-packer
packer init .
cp examples/wazuh-manager.auto.pkrvars.hcl.example wazuh-manager.auto.pkrvars.hcl
# edit wazuh-manager.auto.pkrvars.hcl
packer build -force .
```
