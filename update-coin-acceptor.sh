#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
SERVICE_NAME="coin-acceptor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TARGET_USER="root"
PROJECT_ROOT="/var/www/yt-jukebox-client"
SCRIPT_SRC="coin-acceptor.py"
SCRIPT_DEST="${PROJECT_ROOT}/coin-acceptor.py"

# ==========================================================
# 3. SHUTDOWN EXISTING SERVICE
# ==========================================================
echo "--- Step 3: Managing existing systemd services ---"
if systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
    echo "[INFO] Active ${SERVICE_NAME} daemon detected. Shutting down process..."
    systemctl stop "${SERVICE_NAME}.service" || true
    systemctl disable "${SERVICE_NAME}.service" || true
    echo "[OK] Service stopped and disabled."
else
    echo "[OK] No active service legacy blocks found."
fi

# ==========================================================
# 4. REPLACE AND START SERVICE
# ==========================================================
echo "--- Step 4: Deploying artifacts and systemd activation ---"

# Verify project directory infrastructure exists
mkdir -p "$(dirname "${SCRIPT_DEST}")"

# Ensure correct file runtime ownerships
chown -R "${TARGET_USER}:${TARGET_USER}" "${PROJECT_ROOT}"
chmod +x "${SCRIPT_DEST}"

# Deploy the clean service definition descriptor inline
echo "[INFO] Writing systemd descriptor matrix to ${SERVICE_FILE}..."
cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=Jukebox Coin Acceptor Hardware Service
After=network.target

[Service]
Type=simple
User=${TARGET_USER}
Group=dialout
WorkingDirectory=${PROJECT_ROOT}
ExecStart=python3 ${SCRIPT_DEST}
EnvironmentFile=${PROJECT_ROOT}/.env
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

# Reload and trigger process infrastructure
echo "[INFO] Reloading systemd manager and firing background service..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl start "${SERVICE_NAME}.service"

echo "=== Setup Sequence Complete ==="
systemctl status "${SERVICE_NAME}.service" --no-pager | grep -E "(Active:|Main PID:)"