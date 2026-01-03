#!/usr/bin/env bash
set -euo pipefail

: "${PVE_HOST:?missing PVE_HOST}"
: "${PVE_USER:?missing PVE_USER}"
: "${TEMPLATE_NAME:?missing TEMPLATE_NAME}"

SSH_OPTS="-o StrictHostKeyChecking=no -o BatchMode=yes"

ssh ${SSH_OPTS} "${PVE_USER}@${PVE_HOST}" bash -lc "'
set -euo pipefail

VMID=\$(qm list | awk -v n=\"${TEMPLATE_NAME}\" '\''\$2==n {print \$1; exit}'\'')
[ -n \"\$VMID\" ] || { echo \"[ERR] Cannot find VMID for ${TEMPLATE_NAME}\" >&2; exit 1; }

for i in \$(seq 1 30); do
  qm unlock \"\$VMID\" >/dev/null 2>&1 || true
  qm set \"\$VMID\" -delete net0 >/dev/null 2>&1 && exit 0 || true
  sleep 2
done

echo \"[ERR] Timeout deleting net0 on VMID \$VMID\" >&2
exit 1
'"