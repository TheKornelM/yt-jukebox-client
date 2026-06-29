#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
SERVICE_NAME="coin-acceptor"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TARGET_USER="jukebox"
PROJECT_ROOT="."
SCRIPT_SRC="coin_acceptor.py"
SCRIPT_DEST="${PROJECT_ROOT}/coint_acceptor/coin_acceptor.py"

echo "=== Starting Coin Acceptor Setup ==="

# Check execution privileges
if [ "$EUID" -ne 0 ]; then
    echo "[CRITICAL] Please run this script as root or with sudo."
    exit 1
fi

# ==========================================================
# 1. INSTALL DEPENDENCIES
# ==========================================================
echo "--- Step 1: Checking Python environment and packages ---"

if ! command -v pip3 &> /dev/null; then
    echo "[INFO] pip3 not found. Installing python3-pip..."
    apt-get install python3-pip -y
else
    echo "[OK] pip3 is already installed."
fi

echo "[INFO] Installing required Python libraries..."
# Ensure prerequisites are met globally or at system-level for the user
pip3 install --upgrade pip
pip3 install requests

# Note: OPi.GPIO compilation requires python3-dev headers occasionally
apt-get install python3-dev -y || echo "[WARN] Python dev tools install skipped."
pip3 install OPi.GPIO || echo "[WARN] OPi.GPIO install failed, ensure you are on an Orange Pi."

# ==========================================================
# 2. CREATE JUKEBOX USER AND GROUPS
# ==========================================================
echo "--- Step 2: Provisioning system user profiles ---"
if ! id -u "$TARGET_USER" &> /dev/null; then
    echo "[INFO] User '${TARGET_USER}' does not exist. Generating profile..."
    
    # Generate a secure random 32-character password
    RANDOM_PW=$(openssl rand -base64 24)
    
    # Create system user without interactive shell access for security
    useradd -m -s /bin/false "$TARGET_USER"
    echo "${TARGET_USER}:${RANDOM_PW}" | chpasswd   
    echo "[OK] User '${TARGET_USER}' created successfully with a strong random password."
else
    echo "[OK] User '${TARGET_USER}' already exists."
fi

# Ensure user is mapped to hardware interfaces
echo "[INFO] Assigning '${TARGET_USER}' to hardware interface groups (dialout, gpio)..."
usermod -aG dialout "$TARGET_USER" || echo "[WARN] dialout group mismatch."
# Create gpio group if missing, then append user
groupadd -f gpio
usermod -aG gpio "$TARGET_USER"

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