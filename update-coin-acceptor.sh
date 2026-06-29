#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
SERVICE_NAME="coin-acceptor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TARGET_USER="jukebox"
PROJECT_ROOT="/home/user/yt-jukebox-client"
SCRIPT_SRC="coin_acceptor.py"
SCRIPT_DEST="${PROJECT_ROOT}/coint_acceptor/coin_acceptor.py"

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

# Copy execution script into project deployment sector if found in current runtime dir
if [ -f "${SCRIPT_SRC}" ]; then
    echo "[INFO] Staging ${SCRIPT_SRC} to deployment path..."
    cp "${SCRIPT_SRC}" "${SCRIPT_DEST}"
elif [ -f "coin_acceptor.py" ]; then
    echo "[INFO] Staging localized coin_acceptor.py to deployment path..."
    cp "coin_acceptor.py" "${SCRIPT_DEST}"
else
    echo "[WARN] Source script coin_acceptor.py not found in local workspace path. Ensure it resides at ${SCRIPT_DEST} manually."
fi

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
WorkingDirectory=${PROJECT_ROOT}/infra/scripts
ExecStart=/usr/bin/python3 ${SCRIPT_DEST}
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