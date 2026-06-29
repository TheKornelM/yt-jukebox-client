#!/bin/bash

# Beállítások
TARGET_URL="https://yt-jukebox.duckdns.org"
COIN_SERVICE="coin-acceptor.service"
CHECK_INTERVAL=5

export DISPLAY=:0
export XAUTHORITY=/home/user/.Xauthority

echo "Zenegep inicializalasa elindult..."

# ==========================================================
# 1. ELLENŐRZŐ CIKLUS (Addig fut, amíg a Net VAGY a Hardver hibás)
# ==========================================================
while true; do
    WIFI_UP=false
    COIN_UP=false

    if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
        WIFI_UP=true
    fi

    # Érmeválogató szerviz ellenőrzése
    if systemctl is-active --quiet "$COIN_SERVICE"; then
        COIN_UP=true
    fi

    if [ "$WIFI_UP" = true ] && [ "$COIN_UP" = true ]; then
        echo "[OK] Internet es ermevalogato is uzemkesz. Tovabblepes a feluletre..."
        break
    fi

    # Hibakezelés és javítási kísérlet a várakozás alatt
    echo "[INFO] Várakozás a feltételekre... Wi-Fi: $WIFI_UP | Érmeválogató: $COIN_UP"
    
    if [ "$COIN_UP" = false ]; then
        echo "[HARDVER] Ermevalogato szolgaltatas ($COIN_SERVICE) inditasa..."
        sudo systemctl start "$COIN_SERVICE" --no-block >/dev/null 2>&1 || true
    fi

    sleep "$CHECK_INTERVAL"
done

# ==========================================================
# 2. INDÍTÁS (Csak akkor fut le, ha a fenti ciklus sikeresen lezárult)
# ==========================================================
echo "[OK] Feltételek teljesültek. Chromium indítása Kiosk módban..."

# Elindítjuk a Chromiumot a háttérben, de a script itt már NEM futja újra
exec chromium-browser --kiosk \
    "$TARGET_URL"