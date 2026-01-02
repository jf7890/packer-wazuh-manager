#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Re-run as root if needed (packer ssh user might be 'blue')
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -n -E bash "$0" "$@"
fi

# -------------------------
# Network static IP (NOTE: risky during packer build)
# -------------------------
NET_IF="ens18"
IP_ADDR="10.10.172.10/24"
GATEWAY="10.10.172.1"
DNS_SERVERS="1.1.1.1"
NETPLAN_FILE="/etc/netplan/01-static-ip.yaml"

echo "[+] Writing netplan for ${NET_IF}..."

cat > "${NETPLAN_FILE}" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${NET_IF}:
      dhcp4: false
      addresses:
        - ${IP_ADDR}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses:
          - ${DNS_SERVERS}
EOF

chmod 600 "${NETPLAN_FILE}" || true

# SAFER: generate only. Apply/restart can drop SSH during build.
echo "[+] Netplan generated (apply deferred)."
netplan generate > /dev/null 2>&1 || true

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

echo "[+] Installing filebeat (disabled by default)..."
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

systemctl enable filebeat > /dev/null 2>&1 || true
systemctl start    filebeat > /dev/null 2>&1 || true

echo "[+] Done."
