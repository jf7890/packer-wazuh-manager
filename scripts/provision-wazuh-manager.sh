#!/usr/bin/env bash
set -euo pipefail

# Silence service operations to avoid occupying SSH session.
export DEBIAN_FRONTEND=noninteractive

# Set static ip for Wazuh manager
NET_IF="ens18"
IP_ADDR="10.10.172.10/24"
GATEWAY="10.10.172.1"
DNS_SERVERS="1.1.1.1"

NETPLAN_FILE="/etc/netplan/01-static-ip.yaml"

echo "[+] Configuring static IP for ${NET_IF}..."

cat > "${NETPLAN_FILE}" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${NET_IF}:
      dhcp4: false
      addresses:
        - ${IP_ADDR}
      gateway4: ${GATEWAY}
      nameservers:
        addresses:
          - ${DNS_SERVERS}
EOF

chmod 600 "${NETPLAN_FILE}"

echo "[+] Applying netplan..."
netplan generate > /dev/null 2>&1 || true
netplan apply > /dev/null 2>&1 || true

echo "[+] Restarting systemd-networkd..."
systemctl restart systemd-networkd > /dev/null 2>&1 || trueNET_IF="ens18"
IP_ADDR="10.10.172.10/24"
GATEWAY="10.10.172.1"
DNS_SERVERS="1.1.1.1"

NETPLAN_FILE="/etc/netplan/01-static-ip.yaml"

echo "[+] Configuring static IP for ${NET_IF}..."

cat > "${NETPLAN_FILE}" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${NET_IF}:
      dhcp4: false
      addresses:
        - ${IP_ADDR}
      gateway4: ${GATEWAY}
      nameservers:
        addresses:
          - ${DNS_SERVERS}
EOF

chmod 600 "${NETPLAN_FILE}"

echo "[+] Applying netplan..."
netplan generate > /dev/null 2>&1 || true
netplan apply > /dev/null 2>&1 || true

echo "[+] Restarting systemd-networkd..."
systemctl restart systemd-networkd > /dev/null 2>&1 || true

echo "[+] Updating apt cache..."
apt-get update -y >/dev/null 2>&1 || true

echo "[+] Installing prerequisites..."
apt-get install -y curl gnupg apt-transport-https lsb-release ca-certificates >/dev/null 2>&1 || true

# ---- Wazuh manager install (official repo flow) ----
# NOTE: This script assumes Internet access from the VM during build.
echo "[+] Adding Wazuh repository..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg >/dev/null 2>&1 || true
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

apt-get update -y >/dev/null 2>&1 || true

echo "[+] Installing wazuh-manager..."
apt-get install -y wazuh-manager >/dev/null 2>&1 || true

# Start/enable quietly
systemctl enable wazuh-manager >/dev/null 2>&1 || true
systemctl start wazuh-manager >/dev/null 2>&1 || true

# ---- Filebeat install (kept disabled until cert/indexer is ready) ----
echo "[+] Installing filebeat..."
apt-get install -y filebeat >/dev/null 2>&1 || true

mkdir -p /etc/filebeat/certs >/dev/null 2>&1 || true
: > /etc/filebeat/certs/EMPTY_CERT.pem

cat >/root/WAZUH_CERTS_NOTE.txt <<'EOF'
Cert placeholder created:
- /etc/filebeat/certs/EMPTY_CERT.pem

Replace with real cert/key/CA paths once your Wazuh indexer/certs plan is ready,
then enable and start filebeat:
  systemctl enable filebeat
  systemctl start filebeat
EOF

systemctl disable filebeat >/dev/null 2>&1 || true
systemctl stop filebeat >/dev/null 2>&1 || true

echo "[+] Done."
