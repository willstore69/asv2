#!/usr/bin/env bash
# Installer autoscript_v2 (C++) — ringan 1GB, sharing 80/443
set -e
if [ "$(id -u)" != "0" ]; then echo "Harus root"; exit 1; fi
cd "$(dirname "$0")"
if [ -d src ]; then
echo "[1/5] Build C++ (mode source)..."
if ! command -v c++ >/dev/null; then apt update -y && apt install -y build-essential; fi
make -j$(nproc || echo 2)
else
echo "[1/5] Verifikasi biner rilis (mode prebuilt)..."
[ -f asv2 ] && [ -f asv2-ws ] || { echo "Biner rilis tidak lengkap."; exit 1; }
sha256sum -c CHECKSUMS.sha256 || { echo "Checksum TIDAK COCOK. Hentikan."; exit 1; }
fi
echo "[2/5] Install binary + symlink kompatibel v1..."
if [ -d src ]; then
make install
else
install -m 755 asv2 asv2-ws /usr/local/bin/
for n in add-ssh del-ssh renew-ssh trial-ssh lock-ssh unlock-ssh ban-ssh unban-ssh cek cek-ssh cek-xray add-vmess del-vmess renew-vmess add-vless del-vless add-trojan del-trojan add-vmessgrpc add-vlessgrpc add-trojangrpc add-vmesstcp add-vlessxtls add-l2tp del-l2tp renew-l2tp autoban backup restore change-domain change-port change-uuid argo-setup; do ln -sf asv2 /usr/local/bin/$n; done
echo OK
fi
echo "[3/5] Direktori & token API..."
mkdir -p /etc/william/profile /etc/xray /usr/local/etc/xray /var/log/xray
[ -s /etc/william/profile/api.conf ] || echo "API_TOKEN=$(tr -dc A-Za-z0-9 </dev/urandom | head -c32)" > /etc/william/profile/api.conf
chmod 600 /etc/william/profile/api.conf
echo "[4/5] Systemd (api, bot, ws, mux, autoban)..."
cp -f systemd/*.service systemd/*.timer /etc/systemd/system/ 2>/dev/null || true
systemctl daemon-reload || true
systemctl enable --now asv2-ws asv2-mux asv2-api 2>/dev/null || true
systemctl enable --now asv2-autoban.timer 2>/dev/null || true
# cron cadangan + stats-sync quota (tanpa restart apapun)
(crontab -l 2>/dev/null | grep -v asv2; echo '* * * * * /usr/local/bin/asv2 autoban >/dev/null 2>&1'; echo '* * * * * /usr/local/bin/asv2 stats-sync >/dev/null 2>&1') | crontab - || true
echo "[5/5] Selesai. Lanjut: asv2 setup --domain vpn.kamu.com"
asv2 --help | head -n 20
