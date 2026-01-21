#!/usr/bin/env bash
set -euo pipefail
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Automate per-agent DLS role/user creation and cleanup on Wazuh AIO.
# - Creates role dls-agent-<id> with DLS on wazuh-alerts-* and wazuh-archives-*
# - Creates user <agent_name>-<agent_id> (default password DEFAULT_PASSWORD or CyR4ng3_123)
# - Maps user to DLS role + kibana_user + global_tenant read
# - Removes role/user and agent when disconnected
# - Persists credentials to /root/agent-users.txt (chmod 600)

LOG() { echo "[wazuh-auto-dls] $*" >&2; }

PASSWORDS_FILE="/root/wazuh-passwords.txt"
STATE_FILE="/root/agent-users.txt"
DEFAULT_PASSWORD="${DEFAULT_PASSWORD:-CyR4ng3_123}"
ROLE_UI="${ROLE_UI:-kibana_user}"
INDEXER_URL="${INDEXER_URL:-https://127.0.0.1:9200}"
WAZUH_API_URL="${WAZUH_API_URL:-https://127.0.0.1:55000}"

touch "${STATE_FILE}" >/dev/null 2>&1 || true
chmod 0600 "${STATE_FILE}" >/dev/null 2>&1 || true

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    LOG "Must run as root"
    exit 1
  fi
}

sanitize_name() {
  local raw="$1"
  local cleaned
  cleaned=$(printf '%s' "$raw" | tr -c 'A-Za-z0-9._-' '-' | sed 's/--*/-/g; s/^-//; s/-$//')
  echo "${cleaned:-agent}"
}

parse_indexer_admin() {
  local user pass
  user=$(grep "indexer_username: 'admin'" "${PASSWORDS_FILE}" | head -1 | awk -F"'" '{print $2}')
  pass=$(awk "/indexer_username: 'admin'/{getline; if (\$0 ~ /indexer_password/) {gsub(/.*'/,\"\", \$0); gsub(/'.*/, \"\", \$0); print; exit}}" "${PASSWORDS_FILE}")
  if [[ -z "$user" || -z "$pass" ]]; then
    LOG "Cannot parse indexer admin creds from ${PASSWORDS_FILE}"
    exit 1
  fi
  INDEXER_ADMIN_USER="$user"
  INDEXER_ADMIN_PASS="$pass"
}

parse_api_creds() {
  local user pass
  user=$(grep "api_username: 'wazuh'" "${PASSWORDS_FILE}" | head -1 | awk -F"'" '{print $2}')
  pass=$(awk "/api_username: 'wazuh'/{getline; if (\$0 ~ /api_password/) {gsub(/.*'/,\"\", \$0); gsub(/'.*/, \"\", \$0); print; exit}}" "${PASSWORDS_FILE}")
  if [[ -z "$user" || -z "$pass" ]]; then
    LOG "Cannot parse Wazuh API creds from ${PASSWORDS_FILE}"
    exit 1
  fi
  WAZUH_API_USER="$user"
  WAZUH_API_PASS="$pass"
}

get_wazuh_token() {
  local token
  token=$(curl -sk -u "${WAZUH_API_USER}:${WAZUH_API_PASS}" -X POST \
    "${WAZUH_API_URL}/security/user/authenticate" | jq -r '.data.token // empty')
  if [[ -z "$token" || "$token" == "null" ]]; then
    LOG "Failed to obtain Wazuh API token"
    exit 1
  fi
  WAZUH_TOKEN="$token"
}

call_indexer() {
  local method="$1"; shift
  local path="$1"; shift
  local data="${1:-}"
  if [[ -n "$data" ]]; then
    curl -sk -u "${INDEXER_ADMIN_USER}:${INDEXER_ADMIN_PASS}" -X "$method" \
      -H 'Content-Type: application/json' \
      "${INDEXER_URL}${path}" -d "$data" >/dev/null
  else
    curl -sk -u "${INDEXER_ADMIN_USER}:${INDEXER_ADMIN_PASS}" -X "$method" \
      "${INDEXER_URL}${path}"
  fi
}

fetch_agents() {
  local status="$1"
  curl -sk -H "Authorization: Bearer ${WAZUH_TOKEN}" \
    "${WAZUH_API_URL}/agents?status=${status}&limit=5000" \
    | jq -r '.data.affected_items[] | "\(.id)|\(.name)"'
}

load_state() {
  declare -gA STATE_USER STATE_NAME
  while IFS='|' read -r id user name; do
    [[ -z "$id" || -z "$user" ]] && continue
    STATE_USER["$id"]="$user"
    STATE_NAME["$id"]="$name"
  done < <(grep -v '^#' "${STATE_FILE}" || true)
}

save_state() {
  : > "${STATE_FILE}"
  chmod 0600 "${STATE_FILE}" >/dev/null 2>&1 || true
  for id in "${!STATE_USER[@]}"; do
    echo "${id}|${STATE_USER[$id]}|${STATE_NAME[$id]}" >> "${STATE_FILE}"
  done
}

ensure_roles_mapping_add_user() {
  local role="$1" user="$2"
  local existing body
  existing=$(call_indexer "GET" "/_plugins/_security/api/rolesmapping/${role}" || true)
  if echo "$existing" | jq -e '.[keys[0]]' >/dev/null 2>&1; then
    body=$(echo "$existing" | jq --arg u "$user" '.[keys[0]] as $r | {users:(($r.users // []) + [$u] | unique), backend_roles:($r.backend_roles // []), hosts:($r.hosts // [])}')
  else
    body=$(jq -nc --arg u "$user" '{users:[$u], backend_roles:[], hosts:[]}')
  fi
  call_indexer "PUT" "/_plugins/_security/api/rolesmapping/${role}" "$body"
}

ensure_role() {
  local agent_id="$1" agent_name="$2"
  local role="dls-agent-${agent_id}"
  local username
  username="$(sanitize_name "${agent_name}-${agent_id}")"

  local role_body
  role_body=$(jq -nc \
    --arg aid "$agent_id" \
    '{cluster_permissions:["cluster_composite_ops_ro","indices:data/read/search/template/render"],
      index_permissions:[{index_patterns:["wazuh-alerts-*","wazuh-archives-*"],allowed_actions:["read","indices:data/read/search"],dls:("{\"term\":{\"agent.id\":\"" + $aid + "\"}}")}],
      tenant_permissions:[{tenant_patterns:["global_tenant"],allowed_actions:["kibana_all_read"]}]}' )
  call_indexer "PUT" "/_plugins/_security/api/roles/${role}" "$role_body"

  local user_body
  user_body=$(jq -nc --arg pw "$DEFAULT_PASSWORD" '{password:$pw}')
  call_indexer "PUT" "/_plugins/_security/api/internalusers/${username}" "$user_body"

  ensure_roles_mapping_add_user "${role}" "${username}"
  ensure_roles_mapping_add_user "${ROLE_UI}" "${username}"

  STATE_USER["$agent_id"]="$username"
  STATE_NAME["$agent_id"]="$agent_name"
}

remove_user_from_mapping() {
  local role="$1" user="$2"
  local existing body
  existing=$(call_indexer "GET" "/_plugins/_security/api/rolesmapping/${role}" || true)
  if ! echo "$existing" | jq -e '.[keys[0]]' >/dev/null 2>&1; then
    return 0
  fi
  body=$(echo "$existing" | jq --arg u "$user" '.[keys[0]] as $r | {users:(($r.users // []) - [$u]), backend_roles:($r.backend_roles // []), hosts:($r.hosts // [])}')
  call_indexer "PUT" "/_plugins/_security/api/rolesmapping/${role}" "$body"
}

teardown_agent() {
  local agent_id="$1" agent_name="$2"
  local username role
  role="dls-agent-${agent_id}"
  username="${STATE_USER[$agent_id]:-$(sanitize_name "${agent_name}-${agent_id}")}"

  remove_user_from_mapping "${ROLE_UI}" "${username}"
  call_indexer "DELETE" "/_plugins/_security/api/rolesmapping/${role}" >/dev/null 2>&1 || true
  call_indexer "DELETE" "/_plugins/_security/api/internalusers/${username}" >/dev/null 2>&1 || true
  call_indexer "DELETE" "/_plugins/_security/api/roles/${role}" >/dev/null 2>&1 || true

  if [[ -x /var/ossec/bin/manage_agents ]]; then
    /var/ossec/bin/manage_agents -r "${agent_id}" -f >/dev/null 2>&1 || true
  fi

  unset STATE_USER["$agent_id"]
  unset STATE_NAME["$agent_id"]
}

process_active_agents() {
  local agent_id agent_name
  while IFS='|' read -r agent_id agent_name; do
    [[ -z "$agent_id" ]] && continue
    ensure_role "$agent_id" "$agent_name"
    if ! grep -q "^${agent_id}|" "${STATE_FILE}"; then
      echo "${agent_id}|${STATE_USER[$agent_id]}|${agent_name}" >> "${STATE_FILE}"
      chmod 0600 "${STATE_FILE}" >/dev/null 2>&1 || true
    fi
  done < <(fetch_agents "active" || true)
}

process_disconnected_agents() {
  local agent_id agent_name
  while IFS='|' read -r agent_id agent_name; do
    [[ -z "$agent_id" ]] && continue
    teardown_agent "$agent_id" "$agent_name"
  done < <(fetch_agents "disconnected" || true)
}

main() {
  require_root
  if [[ ! -f "${PASSWORDS_FILE}" ]]; then
    LOG "Missing ${PASSWORDS_FILE}; aborting"
    exit 0
  fi
  parse_indexer_admin
  parse_api_creds
  get_wazuh_token
  load_state
  process_active_agents
  process_disconnected_agents
  save_state
}

main "$@"
