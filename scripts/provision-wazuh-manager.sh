#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Re-run as root if needed
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -n -E bash "$0" "$@"
fi

echo "[+] Starting Wazuh manager provisioning..."

netplan generate > /dev/null 2>&1 || true
echo "[+] Netplan generated (apply deferred)."


# Packages

echo "[+] Updating apt cache..."
apt-get update -y > /dev/null 2>&1 || true

echo "[+] Installing prerequisites..."
apt-get install -y curl gnupg apt-transport-https lsb-release ca-certificates > /dev/null 2>&1 || true

echo "[+] Adding Wazuh repository..."
curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH \
  | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg > /dev/null 2>&1 || true

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  > /etc/apt/sources.list.d/wazuh.list

apt-get update -y > /dev/null 2>&1 || true

echo "[+] Installing wazuh-manager..."
apt-get install -y wazuh-manager > /dev/null 2>&1 || true

systemctl enable wazuh-manager > /dev/null 2>&1 || true
systemctl start  wazuh-manager > /dev/null 2>&1 || true

echo "[+] Installing filebeat..."
apt-get install -y filebeat > /dev/null 2>&1 || true

mkdir -p /etc/filebeat/certs > /dev/null 2>&1 || true
: > /etc/filebeat/certs/EMPTY_CERT.pem

cat > /root/WAZUH_CERTS_NOTE.txt <<'EOF'
Cert placeholder created:
- /etc/filebeat/certs/EMPTY_CERT.pem

Replace with real cert/key/CA paths once your Wazuh indexer/certs plan is ready,
then enable and start filebeat:
  systemctl enable filebeat
  systemctl start filebeat
EOF

# Make netplan stable across boots (cloud-init must not rewrite it)

mkdir -p /etc/cloud/cloud.cfg.d >/dev/null 2>&1 || true
cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<'EOF'
network: {config: disabled}
EOF

# Remove cloud-init generated netplan so ours is authoritative
rm -f /etc/netplan/50-cloud-init.yaml >/dev/null 2>&1 || true

# Write SAFE netplan (keep default route on mgmt/ens18; blue/ens19 static only)
NETPLAN_FILE="/etc/netplan/01-safe-template.yaml"
cat > "${NETPLAN_FILE}" <<'EOF'
  ens18:
    dhcp4: false
    dhcp6: false
    addresses:
      - 10.10.172.10/24
    routes:
      - to: default
        via: 10.10.172.1
    nameservers:
      addresses: [1.1.1.1]
    optional: true
EOF
chmod 0644 "${NETPLAN_FILE}" >/dev/null 2>&1 || true

systemctl stop wazuh-manager > /dev/null 2>&1 || true
systemctl stop filebeat      > /dev/null 2>&1 || true
systemctl disable filebeat   > /dev/null 2>&1 || true

sleep 10 || true
sync || true

echo "[+] Template cleanup (keys/identity/logs)..."

# Remove build-time keys
rm -f /root/.ssh/authorized_keys || true
rm -f /home/ubuntu/.ssh/authorized_keys || true

# Lock passwords (optional but recommended for template)
passwd -l ubuntu > /dev/null 2>&1 || true
passwd -l root   > /dev/null 2>&1 || true

# Reset SSH host keys so clones regenerate unique keys
rm -f /etc/ssh/ssh_host_* || true

# cloud-init clean so clone will re-run datasource and accept injected key
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init clean --logs > /dev/null 2>&1 || true
fi

netplan generate > /dev/null 2>&1 || true
netplan apply    > /dev/null 2>&1 || true

# Reset machine-id
truncate -s 0 /etc/machine-id || true
rm -f /var/lib/dbus/machine-id || true

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \; || true

sync || true

echo "[+] Done."