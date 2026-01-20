#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Re-run as root if needed
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -n -E bash "$0" "$@"
fi

echo "[+] Starting Wazuh AIO provisioning..."

# ----------------------------
# (Optional) Netplan handling
# ----------------------------
# NOTE: YAML bạn đang ghi trước đó bị thiếu header "network/version/ethernets".
# Mình giữ logic của bạn (ens18 static + default gw), chỉ sửa YAML cho đúng.
mkdir -p /etc/cloud/cloud.cfg.d >/dev/null 2>&1 || true
cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<'EOF'
network: {config: disabled}
EOF

rm -f /etc/netplan/50-cloud-init.yaml >/dev/null 2>&1 || true
echo "[+] Writing netplan..."
NET_IF="ens18"
IP_CIDR="172.16.99.11/24"
GATEWAY="172.16.99.1"
DNS1="1.1.1.1"
DNS2="8.8.8.8"
NETPLAN_FILE="/etc/netplan/01-safe-template.yaml"
cat > "${NETPLAN_FILE}" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${NET_IF}:
      dhcp4: false
      dhcp6: false
      addresses:
        - ${IP_CIDR}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses:
          - ${DNS1}
          - ${DNS2}
      optional: true
EOF
chmod 0644 "${NETPLAN_FILE}" >/dev/null 2>&1 || true

# Generate/apply netplan (nếu bạn sợ rớt SSH, có thể comment dòng apply)
netplan generate >/dev/null 2>&1 || true

# ----------------------------
# Install prerequisites
# ----------------------------
echo "[+] Installing prerequisites..."
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y curl tar ca-certificates jq >/dev/null 2>&1 || true

# ----------------------------
# Wazuh AIO install (Quickstart)
# ----------------------------
WAZUH_VER="4.14"   # theo quickstart current tại thời điểm mình mở doc :contentReference[oaicite:2]{index=2}
cd /root

echo "[+] Downloading Wazuh installation assistant..."
curl -sO "https://packages.wazuh.com/${WAZUH_VER}/wazuh-install.sh"

echo "[+] Running Wazuh AIO installer..."
# Theo quickstart: sudo bash ./wazuh-install.sh -a :contentReference[oaicite:3]{index=3}
bash ./wazuh-install.sh -a

# ----------------------------
# Export passwords to TXT (per docs)
# ----------------------------
# Doc: sudo tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt :contentReference[oaicite:4]{index=4}
echo "[+] Exporting wazuh-passwords.txt..."
if [[ -f /root/wazuh-install-files.tar ]]; then
  tar -O -xvf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt \
    > /root/wazuh-passwords.txt
  chmod 0600 /root/wazuh-passwords.txt >/dev/null 2>&1 || true
else
  echo "[!] wazuh-install-files.tar not found. Password export skipped."
fi

# ----------------------------
# Add custom rules (local rules)
# ----------------------------
echo "[+] Installing custom local rules..."
RULES_DIR="/var/ossec/etc/rules"
RULES_FILE="${RULES_DIR}/local_rules.xml"
install -d -m 0750 "${RULES_DIR}" >/dev/null 2>&1 || true

# Tạo file nếu chưa có
if [[ ! -f "${RULES_FILE}" ]]; then
  cat > "${RULES_FILE}" <<'EOF'
<group name="local,">
</group>
EOF
fi

# Append rules nếu chưa có rule id 100000
if ! grep -q 'rule id="100000"' "${RULES_FILE}"; then
  cat >> "${RULES_FILE}" <<'EOF'

<group name="custom,web,fim,attack_chain,">

  <!-- ================= BASE WEB EVENT ================= -->

  <rule id="100000" level="2">
    <if_group>json</if_group>
    <field name="transaction.producer.modsecurity">.</field>
    <description>ModSecurity log detected</description>
  </rule>

  <!-- ================= SQL INJECTION ================= -->

  <rule id="100010" level="10">
    <if_sid>100000</if_sid>
    <regex>942100|attack-sqli|SQL Injection</regex>
    <description>SQL Injection attempt detected</description>
    <mitre>
      <id>T1190</id>
    </mitre>
  </rule>

  <!-- ================= SQL Blocked ================= -->

  <rule id="100021" level="12">
    <if_sid>100010</if_sid>
    <field name="transaction.response.http_code">403</field>
    <description>SQL Injection blocked by WAF</description>
  </rule>

  <!-- ================= SQL success ================= -->

  <rule id="100022" level="8">
    <if_sid>100010</if_sid>
    <field name="transaction.response.http_code">200</field>
    <description>SQL Injection successful (HTTP 200)</description>
  </rule>

  <!-- ================= FIM ================= -->

  <rule id="100100" level="8">
    <if_group>syscheck</if_group>
    <field name="syscheck.event">added</field>
    <description>File added to system</description>
  </rule>

  <rule id="100101" level="10">
    <if_sid>100100</if_sid>
    <field name="syscheck.path">/dvwa_upload/</field>
    <description>File uploaded to web directory</description>
    <mitre>
      <id>T1505</id>
    </mitre>
  </rule>

  <rule id="100102" level="13">
    <if_sid>100101</if_sid>
    <field name="syscheck.path">.php</field>
    <description>Webshell file detected (.php)</description>
    <mitre>
      <id>T1505</id>
    </mitre>
  </rule>

  <!-- ================= CORRELATION ================= -->

  <rule id="100200" level="15">
    <if_matched_sid>100010</if_matched_sid>
    <if_matched_sid>100101</if_matched_sid>
    <description>ATTACK CHAIN: SQL Injection followed by file upload</description>
    <mitre>
      <id>T1190</id>
      <id>T1505</id>
    </mitre>
  </rule>

</group>
EOF
fi

# quyền file rules (thường group ossec)
chown root:ossec "${RULES_FILE}" >/dev/null 2>&1 || true
chmod 0640 "${RULES_FILE}" >/dev/null 2>&1 || true

# Reload rules (restart manager)
systemctl restart wazuh-manager >/dev/null 2>&1 || true

# ----------------------------
# Disable Wazuh repo after install (recommended by docs)
# ----------------------------
# Quickstart khuyến nghị disable repo để tránh upgrade làm vỡ môi trường :contentReference[oaicite:5]{index=5}
if [[ -f /etc/apt/sources.list.d/wazuh.list ]]; then
  sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/wazuh.list || true
  apt-get update -y >/dev/null 2>&1 || true
fi

# ----------------------------
# Optional: stop services before templating (giảm rủi ro “kẹt” khi stop VM)
# ----------------------------
systemctl stop wazuh-manager   >/dev/null 2>&1 || true
systemctl stop wazuh-indexer   >/dev/null 2>&1 || true
systemctl stop wazuh-dashboard >/dev/null 2>&1 || true
sleep 5 || true
sync || true

echo "[+] Template cleanup (SSH keys / identity)..."

echo "[+] 1) Remove build-time authorized_keys"
rm -f /root/.ssh/authorized_keys || true
rm -f /home/ubuntu/.ssh/authorized_keys || true

echo "[+] Reset SSH host keys so clones regenerate unique keys on first boot"
rm -f /etc/ssh/ssh_host_* || true

echo "[+] Clean cloud-init so clone can re-run datasource and accept new injected keys"
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init clean --logs >/dev/null 2>&1 || true
fi

echo "[+] Reset machine-id to avoid clones sharing identity"
truncate -s 0 /etc/machine-id || true
rm -f /var/lib/dbus/machine-id || true

sync || true

echo "[+] Done."
