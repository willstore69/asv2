# autoscript_v2 (C++) — SEMUA TLS=443, SEMUA NTLS=80, ringan 1GB

Rewrite total `autoscript/` (bash ~181 file) menjadi **C++17 modern**, 2 binary kecil:

- `asv2` (±500KB) — multicall CLI modern (`asv2 menu`): setup, SSH/XRAY/L2TP CRUD **tanpa restart**, cek login+quota, autoban, lock/unban, quota/limit, path /anything, change domain/uuid, backup/restore, API, Bot.
- `asv2-ws` (±150KB) — direct SSH-WS + **demux router `/anything`** (rewrite path custom → kanonis, live tanpa restart).

Detail desain: `docs/PORTS_PATHS.md`. REST: `docs/API.md`.

## Kenapa ringan?

- Tanpa python/jq loop berat, tanpa stunnel/sslh ganda.
- **443 (SEMUA TLS)**: 1x Xray `VLESS-XTLS-VISION` terminator + fallbacks → demux 3090 (WS /anything, ssh-ws, web, trojan-TCP) & nginx-h2 8444 (grpc).
- **80 (SEMUA NTLS)**: nginx → demux 3090 bila `Upgrade: websocket`, `grpc_pass` per-serviceName, sisanya web.
- **1 proses xray** (dulu 3: xray, xray@none, argo-xray). Argo tetap opsional via cloudflared.
- Binary static-ish, RSS `<10MB`, cocok VPS 1GB.

## Tanpa restart (tanpa DC 1–3 detik)

CRUD/ban/unban/renew/ganti-UUID Xray via gRPC `HandlerService/AlterInbound`
native (`src/grpc.cpp`, tanpa library) — koneksi user lain utuh.
Satu-satunya restart: `setup` awal & `apply-paths` (eksplisit + konfirmasi).

## Protokol (tetap sama)

- SSH: OpenSSH 22, Dropbear 109/143, Squid 3128, UDPGW 7100-7300, WS HTTP 80, WS HTTPS 443 (sharing), UDP 1-65535, SlowDNS 5300, OVPN TCP 1194 / UDP 2200 / SSL 442 / WS 2095
- L2TP: 1701 (xl2tpd+ppp)
- VMESS: ws, grpc, tcp(http), upgrade, xhttp
- VLESS: ws, grpc, xtls(vision), upgrade, xhttp
- TROJAN: ws, grpc, tcp, upgrade, xhttp
- HCR relay :8811 (auto TLS+NTLS, auth user/pass SSH — ikut quota/limit SSH)

## Build

```bash
make -j$(nproc)
sudo make install
```

## Setup cepat

```bash
sudo ASV2_NO_LICENSE=1 ./asv2 setup --domain vpn.contoh.com --ns dns.vpn.contoh.com
sudo asv2 argo-setup --id cf@mail.com --key GLOBAL_API_KEY --domain contoh.com
```

## Contoh CLI (menu modern: `asv2 menu`)

```bash
asv2 add-ssh --user budi --pass rahasia --days 30 --limit 2 --quota 50
asv2 add-vmess --user budi --days 30 --quota 50 --limit 2 --net ws --path /punya-budi
asv2 add-vless --user budi --days 30 --net grpc
asv2 add-trojan --user budi --days 30 --net ws --path /x
asv2 set-path --proto vmess --net ws --path /global-baru   # lalu: asv2 apply-paths --yes
asv2 list-paths
asv2 del-xray --proto vmess --net ws --user budi
asv2 renew-xray --proto vless --net ws --user budi --days 30
asv2 cek-ssh ; asv2 cek-xray
asv2 autoban            # cron tiap menit
asv2 stats-sync         # cron 5 mnt (quota dari StatsService)
asv2 lock-xray --user budi ; asv2 unlock-xray --user budi
asv2 quota --user budi --gb 100
asv2 limit --kind vless-ws --user budi --n 2
asv2 change-domain --domain baru.com
asv2 change-uuid --user budi --uuid $(cat /proc/sys/kernel/random/uuid)
asv2 block-torrent on ; asv2 block-scanner on
asv2 backup ; asv2 restore --file /root/IP-tgl.zip
asv2 api --port 8089 &
asv2 bot &
asv2-ws --port 3001 --tport 22 &   # SSH-WS direct
asv2-ws mux --port 3090 &          # demux /anything (systemd: asv2-mux)
```

Kompatibel symlink v1: `add-ssh`, `add-vmess`, `cek-xray`, `autoban`, dll → `asv2`.

## Bot (1 bot, multi-server)

`/etc/william/profile/bot.conf`:
```
BOT_TOKEN=123:ABC
ADMIN_IDS=111,222
```
`/etc/william/profile/servers.list`:
```
s1|http://10.0.0.2:8089|tokenA
s2|http://10.0.0.3:8089|tokenB
```
Perintah: `/menu /cekssh /cekxray /addssh /addvm u hari quota limit --path /bebas /addvl /addtr /delvm /quota /limit /banxray /unbanxray /paths /setpath vmess ws /baru /backup /srv s1 cek-xray`

Lihat `docs/API.md` untuk REST, `docs/PORTS_PATHS.md` untuk desain port/path/no-restart,
`docs/POLICY.md` untuk quota & limit koneksi.
