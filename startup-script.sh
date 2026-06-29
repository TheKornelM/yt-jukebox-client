#!/bin/bash

TARGET_URL="https://yt-jukebox.duckdns.org"
VPN_INTERFACE="wg0"
COIN_SERVICE="coin-acceptor.service"
CHECK_INTERVAL=5

export DISPLAY=:0
export XAUTHORITY=/home/user/.Xauthority

echo "Zenegep halozati, kijelzo es hardver ellenorzo elindult..."

while true; do
    WIFI_UP=false
    VPN_UP=false

    # Külső internet kapcsolat ellenőrzése
    if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
        WIFI_UP=true
    fi

    # Belső WireGuard VPN átjáró ellenőrzése
    if ping -c 1 -W 2 10.8.0.1 >/dev/null 2>&1; then
        VPN_UP=true
    fi

    # Rendszer állapot ellenőrzési blokk
    if [ "$WIFI_UP" = true ] && [ "$VPN_UP" = true ]; then
        
        if ! systemctl is-active --quiet "$COIN_SERVICE"; then
            echo "[FIGYELMEZTETÉS] Az ermevalogato szolgaltatas leallt. Újraindítás a grafikus felület előtt: ${COIN_SERVICE}..."
            sudo systemctl start "$COIN_SERVICE"
            sleep 1
        fi

        # 2. Második ellenőrzés: Chromium Kiosk böngésző futtatása
        if systemctl is-active --quiet "$COIN_SERVICE"; then
            if ! pgrep -x "chromium-brows" > /dev/null; then
                echo "[OK] Hardver es halozat ellenorizve. Chromium bongeszo inditasa Kiosk modban..."
                chromium-browser --kiosk \
                                 --no-first-run \
                                 --noerrdialogs \
                                 --disable-infobars \
                                 --disable-session-crashed-bubble \
                                 "$TARGET_URL" &
            fi
        else
            echo "[KRITIKUS] A Chromium inditasa nem sikerult, mert a(z) ermevalogato szolgaltatas (${COIN_SERVICE}) nem tudott elindulni."
        fi
        
    else
        echo "[FIGYELMEZTETÉS] Hálózati hiba lépett fel. Várakozás... Wi-Fi: $WIFI_UP | VPN: $VPN_UP"
        
        if pgrep -x "chromium-brows" > /dev/null; then
            echo "[INFO] Kapcsolat megszakadt, Chromium leallitasa a biztonsag erdekeben..."
            pkill -x "chromium-brows"
        fi
    fi

    sleep "$CHECK_INTERVAL"
done