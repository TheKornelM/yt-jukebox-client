#!/bin/bash

set -e

# Target paths definition schema
SERVICE_NAME="jukebox-startup"
SERVICE_SRC="jukebox-startup.service"
SERVICE_DEST="/etc/systemd/system/${SERVICE_NAME}.service"
SUDOERS_FILE="/etc/sudoers.d/${SERVICE_NAME}"
PROJECT_ROOT="/var/www/yt-jukebox-client"
SCRIPT_DEST="${PROJECT_ROOT}/coin-acceptor/startup/startup-script.sh"

echo "=== Starting Jukebox Startup Deployment ==="

# Check context execution permissions
if [ "$EUID" -ne 0 ]; then
    echo "[CRITICAL] Please execute this installation profile as root or via sudo."
    exit 1
fi

# 1. Enforce structural workspace paths and file permission bounds
if [ ! -f "${SCRIPT_DEST}" ]; then
    echo "[WARN] Target source file ${SCRIPT_DEST} is absent. Verification required."
else
    echo "[INFO] Optimizing supervisor execution rights..."
    chmod +x "${SCRIPT_DEST}"
    chown -R user:user "$(dirname "${SCRIPT_DEST}")"
fi

# 2. Deploy the native passwordless systemctl authorization hook
echo "[INFO] Injecting explicit passwordless systemctl sudoers token override..."
echo "user ALL=(ALL) NOPASSWD: /usr/bin/systemctl start coin-acceptor.service" > "${SUDOERS_FILE}"
chmod 0440 "${SUDOERS_FILE}"

# 3. Copy the systemd service descriptor asset directly from repository
echo "[INFO] Staging service configuration file from ${SERVICE_SRC}..."
if [ -f "${SERVICE_SRC}" ]; then
    cp "${SERVICE_SRC}" "${SERVICE_DEST}"
    chmod 0644 "${SERVICE_DEST}"
else
    echo "[CRITICAL] Source configuration file not found at ${SERVICE_SRC}. Aborting deployment."
    exit 1
fi

# 4. Flush changes down to the active manager thread pool
echo "[INFO] Reloading daemon registry context and cycling supervisor processes..."
systemctl daemon-reload
systemctl stop "${SERVICE_NAME}.service" || true
systemctl enable "${SERVICE_NAME}.service"
systemctl start "${SERVICE_NAME}.service"

echo "=== Supervisor Configuration Layer Successfully Installed ==="
systemctl status "${SERVICE_NAME}.service" --no-pager | grep -E "(Active:|Main PID:)"