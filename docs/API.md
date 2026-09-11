# ASV2 REST API — `asv2 api --port 8089` (listen 127.0.0.1, reverse-proxy via nginx bila perlu publik)

Auth: `X-Token: <token>` atau `?token=`. Token di `/etc/william/profile/api.conf`:
```
API_TOKEN=isi-random-panjang
```
Kosong = tanpa auth (hanya untuk localhost/dev).

## Health & Doc

```
GET /api/health -> {"ok":true,"svc":"asv2"}
GET /api/doc
```

## SSH (quota+limit termasuk di cek)

```
GET /api/cek-ssh
GET /api/add-ssh?user=U&pass=P&days=30&limit=2
GET /api/del-ssh?user=U
GET /api/lock-ssh?user=U
GET /api/unlock-ssh?user=U
GET /api/ban-ssh?user=U
GET /api/unban-ssh?user=U
```

## XRAY (100% tanpa restart — gRPC HandlerService native)

```
GET /api/cek-xray
POST /api/add-xray?proto=vmess&net=ws&user=U&days=30&quota=50&limit=2&path=/bebas
  -> {"ok":true,"uuid":"...","link":"vmess://...:443...","link_ntls":"vmess://...:80..."}
GET /api/del-xray?proto=vless&net=ws&user=U
GET /api/renew-xray?proto=vmess&net=ws&user=U&days=30
GET /api/lock-xray?user=U
GET /api/unlock-xray?user=U
GET /api/change-uuid?user=U&uuid=...
```

`proto`: vmess|vless|trojan — `net`: ws|grpc|tcp|xtls|upgrade|xhttp.
`path` opsional (WS/upgrade): path custom /anything per user, aktif instan.
SEMUA TLS=:443, SEMUA NTLS=:80 — respons selalu berisi kedua link.

## Paths & stats

```
GET /api/set-path?proto=vmess&net=ws&path=/baru   (global; lalu apply-paths)
GET /api/list-paths
GET /api/stats-sync  -> {"ok":true,"users":N}  (tarik StatsService -> usage)
```

## Quota / Limit / L2TP / Backup

```
GET /api/quota?user=U&gb=100        (0 = no limit; budget gabungan Xray+SSH)
GET /api/quota-status?user=U        (pakai/limit/sisa)
GET /api/conn                       (sesi SSH live + IP unik Xray)
GET /api/limit?kind=ssh&user=U&n=2  (kind: ssh|vmess-ws|vless-ws|trojan-ws|vmess-grpc|...)
GET /api/add-l2tp?user=U&pass=P&days=30
GET /api/del-l2tp?user=U
GET /api/backup
```

## curl contoh

```bash
T=$(cat /etc/william/profile/api.conf | cut -d= -f2)
curl -H "X-Token: $T" 'http://127.0.0.1:8089/api/add-xray?proto=vless&net=ws&user=budi&days=30&quota=50&limit=2'
curl -H "X-Token: $T" 'http://127.0.0.1:8089/api/cek-xray'
curl -H "X-Token: $T" 'http://127.0.0.1:8089/api/quota?user=budi&gb=100'
```

## Bot ↔ API

Bot (`asv2 bot`) memanggil fungsi C++ langsung untuk server lokal,
dan meneruskan `/srv <label> <endpoint>?...` ke `baseUrl/api/...` untuk server remote.
Satu bot Telegram dapat mengelola N VPS.
