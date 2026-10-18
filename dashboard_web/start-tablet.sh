#!/data/data/com.termux/files/usr/bin/bash
# start-tablet.sh — sobe mosquitto + HTTP server do dashboard.
# Uso: bash ~/start-tablet.sh

# Evita o Android matar os processos em background
termux-wake-lock

echo "[*] Matando processos antigos..."
pkill mosquitto 2>/dev/null
pkill -f 'python3 -m http.server' 2>/dev/null
sleep 1

echo "[*] Subindo mosquitto (1883 + 9001/WS)..."
mosquitto -c /data/data/com.termux/files/usr/etc/mosquitto/mosquitto.conf -d
sleep 1

echo "[*] Subindo HTTP server (8080)..."
cd ~/dashboard
nohup python3 -m http.server 8080 --bind 0.0.0.0 > ~/http.log 2>&1 &

sleep 1
echo ""
echo "[*] Estado:"
netstat -tlnp 2>/dev/null | grep -E '1883|9001|8080'
echo ""
echo "[✓] Pronto."
echo "    Mosquitto: 1883 (TCP) + 9001 (WebSocket)"
echo "    Dashboard: http://localhost:8080"
