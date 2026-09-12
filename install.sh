#!/usr/bin/env bash
# Installer autoscript_v2 (prebuilt, tanpa source, tanpa build).
# Isi repo rilis: file ini + biner. Semua unit systemd ditanam di sini.
set -e
if [ "$(id -u)" != "0" ]; then echo "Harus root"; exit 1; fi
cd "$(dirname "$0")"
echo "[1/4] Verifikasi biner rilis..."
[ -f asv2 ] && [ -f asv2-ws ] || { echo "Biner rilis tidak lengkap."; exit 1; }
sha256sum -c CHECKSUMS.sha256 || { echo "Checksum TIDAK COCOK. Hentikan."; exit 1; }
echo "[2/4] Install binary + symlink..."
install -m 755 asv2 asv2-ws /usr/local/bin/
for n in add-ssh del-ssh renew-ssh trial-ssh lock-ssh unlock-ssh ban-ssh unban-ssh cek cek-ssh cek-xray add-vmess del-vmess renew-vmess add-vless del-vless add-trojan del-trojan add-vmessgrpc add-vlessgrpc add-trojangrpc add-vmesstcp add-vlessxtls add-l2tp del-l2tp renew-l2tp autoban backup restore change-domain change-port change-uuid argo-setup; do ln -sf asv2 /usr/local/bin/$n; done
echo "[3/4] Direktori & token API..."
mkdir -p /etc/william/profile /etc/xray /usr/local/etc/xray /var/log/xray
[ -s /etc/william/profile/api.conf ] || echo "API_TOKEN=$(tr -dc A-Za-z0-9 </dev/urandom | head -c32)" > /etc/william/profile/api.conf
chmod 600 /etc/william/profile/api.conf
echo "[4/4] Systemd (api, bot, ws, mux, autoban) + cron..."
cat > /etc/systemd/system/asv2-ws.service <<'UNIT'
[Unit]
Description=ASV2 WS bridge (127.0.0.1:3001 -> SSH 22, sharing 80/443)
After=network.target
[Service]
ExecStart=/usr/local/bin/asv2-ws --listen 127.0.0.1 --port 3001 --target 127.0.0.1 --tport 22
Restart=always
RestartSec=2
MemoryMax=40M
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
UNIT
cat > /etc/systemd/system/asv2-mux.service <<'UNIT'
[Unit]
Description=ASV2 demux (127.0.0.1:3090, router WS /anything, live reload routes)
After=network.target
[Service]
ExecStart=/usr/local/bin/asv2-ws mux --port 3090
Restart=always
RestartSec=2
MemoryMax=40M
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
UNIT
cat > /etc/systemd/system/asv2-api.service <<'UNIT'
[Unit]
Description=ASV2 API (REST 127.0.0.1:8089)
After=network.target
[Service]
ExecStart=/usr/local/bin/asv2 api --port 8089
Restart=always
RestartSec=3
MemoryMax=80M
[Install]
WantedBy=multi-user.target
UNIT
cat > /etc/systemd/system/asv2-bot.service <<'UNIT'
[Unit]
Description=ASV2 Telegram Bot (1 bot multi-server)
After=network.target asv2-api.service
[Service]
ExecStart=/usr/local/bin/asv2 bot
Restart=always
RestartSec=5
MemoryMax=60M
[Install]
WantedBy=multi-user.target
UNIT
cat > /etc/systemd/system/asv2-autoban.service <<'UNIT'
[Unit]
Description=ASV2 Autoban (SSH+XRAY quota & multi-login)
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/asv2 autoban
MemoryMax=50M
UNIT
cat > /etc/systemd/system/asv2-autoban.timer <<'UNIT'
[Unit]
Description=ASV2 Autoban timer (tiap menit)
[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=asv2-autoban.service
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload || true
systemctl enable --now asv2-ws asv2-mux asv2-api 2>/dev/null || true
systemctl enable --now asv2-autoban.timer 2>/dev/null || true
(crontab -l 2>/dev/null | grep -v asv2; echo '* * * * * /usr/local/bin/asv2 autoban >/dev/null 2>&1'; echo '* * * * * /usr/local/bin/asv2 stats-sync >/dev/null 2>&1') | crontab - || true
echo "Selesai. Lanjut: asv2 setup --domain vpn.kamu.com"
asv2 --help | head -n 8
