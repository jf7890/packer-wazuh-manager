#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  timezone: Asia/Ho_Chi_Minh

  identity:
    hostname: ${hostname}
    username: ubuntu
    password: "${ubuntu_password_hash}"

  ssh:
    install-server: true
    allow-pw: true
    authorized-keys:
      - ${ssh_public_key}

  network:
    version: 2
    ethernets:
      ens18:
        dhcp4: false
        dhcp6: false
        addresses:
          - 10.10.172.10/24
        routes:
          - to: default
            via: 10.10.172.1
        nameservers:
          addresses:
            - 1.1.1.1

  packages:
    - qemu-guest-agent
    - curl
    - ca-certificates

  late-commands:
    - curtin in-target --target=/target -- systemctl enable qemu-guest-agent > /dev/null 2>&1 || true
    - curtin in-target --target=/target -- systemctl start  qemu-guest-agent > /dev/null 2>&1 || true
    - curtin in-target --target=/target -- systemctl enable systemd-networkd > /dev/null 2>&1 || true
    - curtin in-target --target=/target -- netplan generate > /dev/null 2>&1 || true
    - curtin in-target --target=/target -- netplan apply    > /dev/null 2>&1 || true
