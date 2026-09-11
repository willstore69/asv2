#!/usr/bin/env bash
# Migrasi v1 -> v2: path sudah kompatibel (/etc/xray/domain, /usr/local/etc/xray/*.json, /etc/william/*)
# Script ini hanya backup + build + install v2 berdampingan.
set -e
cp -a /usr/local/etc/xray/config.json /root/xray-config-v1.bak.json 2>/dev/null || true
cp -a /etc/xray/domain /root/domain-v1.bak 2>/dev/null || true
cd "$(dirname "$0")/.."
make -j$(nproc) && make install
echo "Migrasi siap. Config v1 tetap terbaca v2 (marker ### & limit/quota sama)."
echo "Jalankan: asv2 cek-xray ; asv2 cek-ssh"
