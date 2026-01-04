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
      - ${pub_key}

  network:
    version: 2
    ethernets:
      ens18:
        dhcp4: true
        dhcp6: false
        optional: true

  packages:
    - qemu-guest-agent
    - curl
    - ca-certificates

  late-commands:
    - curtin in-target --target=/target -- bash -c 'install -d -m 0700 /root/.ssh'
    - curtin in-target --target=/target -- bash -c 'printf "%s\n" "${pub_key}" > /root/.ssh/authorized_keys && chmod 0600 /root/.ssh/authorized_keys'
    - curtin in-target --target=/target -- bash -c 'passwd -u root > /dev/null 2>&1 || true; passwd -d root > /dev/null 2>&1 || true'

    - curtin in-target --target=/target -- bash -c 'install -m 0644 /dev/null /etc/ssh/sshd_config.d/99-root.conf'
    - curtin in-target --target=/target -- bash -c 'printf "%s\n" "PermitRootLogin prohibit-password" "PubkeyAuthentication yes" >> /etc/ssh/sshd_config.d/99-root.conf'

    - curtin in-target --target=/target -- systemctl enable ssh > /dev/null 2>&1 || true
    - curtin in-target --target=/target -- systemctl reload ssh > /dev/null 2>&1 || true
