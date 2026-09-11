# ASV2 v2.1 — SEMUA TLS=443, SEMUA NTLS=80, path /anything, CRUD tanpa restart

## 1. Peta port (final)

```
Internet
  :443 ──> Xray VLESS-XTLS-VISION (terminator TLS, alpn h2+http/1.1)
  │          fallbacks:
  │           · alpn "h2" ──────────> 127.0.0.1:8444 nginx-h2 ──> grpc per-serviceName
  │           · default ────────────> 127.0.0.1:3090 DEMUX (asv2-ws mux)
  :80 ───> nginx (h1 + h2c)
             · Upgrade: websocket ──> 127.0.0.1:3090 DEMUX
             · /<grpc-svc>/ ────────> grpc_pass 127.0.0.1:3005/3006/3007
             · lainnya ────────────> web 127.0.0.1:8081

DEMUX 3090 (baca routes.tsv LIVE tiap koneksi, tanpa restart):
  path terdaftar kind=xray -> tulis-ulang ke path kanonis -> 127.0.0.1:3002/3003/3004/3011-16
  (WS, upgrade, dan XHTTP semua lewat sini; query XHTTP dipertahankan)
  path /ssh-ws (kind=ssh)  -> terminasi WS -> TCP 127.0.0.1:22
  path tak dikenal + WS    -> 404 | tanpa WS -> web 8081
  bukan HTTP (trojan-TCP limpahan 443) -> 127.0.0.1:3010
```

Satu set inbound 127.0.0.1 melayani TLS **dan** NTLS sekaligus
(TLS diterminasi di tepi; inbound `security:none`). Tidak ada lagi
duplikasi config.json/none.json — `none.json` hanya stub kompatibel v1.
API tunggal `127.0.0.1:10085`.

## 2. Path bebas /anything

- **Global/kanonis** per tag (`/etc/william/paths/vmess-ws`, ...):
  `asv2 set-path --proto vmess --net ws --path /bebasku`
  lalu `asv2 apply-paths --yes` (me-restart xray — jeda sesaat, hanya saat
  admin eksplisit setuju). Berlaku untuk ws/upgrade/grpc/tcp.
- **Per-user** (WS & HTTPUpgrade saja):
  `asv2 add-vmess --user budi --days 30 --path /punya-budi`
  Rute ditulis ke `routes.tsv`; demux membaca ulang tiap koneksi → **aktif
  detik itu juga, tanpa restart, tanpa ganggu user lain.**
  Link TLS (:443) & NTLS (:80) memakai path custom otomatis.
- gRPC per-user custom path TIDAK didukung (keterbatasan routing h2:
  serviceName terikat inbound; butuh inbound per user = boros RAM).
  Untuk path bebas per user, pakai WS/Upgrade.
- **AUTOPATH (tanpa daftar sama sekali, default ON)** — WS path APAPUN
  (vmess/vless/trojan/ssh) langsung jalan di :443 + :80 tanpa perintah apa pun:
  demux menerima handshake di path tak dikenal, membaca frame pertama,
  mengenali protokol dari ISINYA (`SSH-` / 56hex+CRLF trojan /
  byte-0 + UUID vless terdaftar / sisanya vmess), membuka handshake baru ke
  inbound yang tepat, lalu relay buta dua arah (frame asli diteruskan utuh).
  Tanpa crypto, tanpa tebak user — auth tetap di xray, quota xray via email,
  quota SSH via korelasi /proc. Matikan bila ingin ketat:
  `asv2 autopath off` (path tak dikenal → 404 seperti dulu).

## 3. Tanpa restart — cara kerja & garansi

Hasil riset Xray (docs + issue #1060/#2596): **Xray tidak punya hot-reload
config**; `restart`/`reload` memutus koneksi aktif (inilah DC 1–3 detik di
script lama yang me-restart tiap create/delete).

ASV2 v2.1 memakai jalur resmi yang sama dengan panel modern (3x-ui,
Marzban): **gRPC `HandlerService/AlterInbound`**:

- tambah user → `AddUserOperation{User{email, Account}}`
- hapus user → `RemoveUserOperation{email}`
- ganti UUID → remove + add (email sama, tanpa restart)
- ban → remove via API + tandai file; unban → add via API
- quota → `StatsService/GetStats` (`user>>>email>>>traffic>>>up/down`)

Client gRPC ditulis tangan di `src/grpc.cpp` (protobuf + HPACK Huffman +
HTTP/2, tanpa library) agar binary tetap <500KB dan RSS <10MB.
Type-URL `xray.*` dengan fallback `v2ray.core.*` untuk core lama.
File config tetap ditulis (persistensi reboot), tetapi **tidak pernah
dibaca-ulang paksa**: tidak ada `restart`/`reload` di path CRUD/ban/renew.
Satu-satunya restart yang tersisa: `setup` awal dan `apply-paths`
(eksplisit, dengan konfirmasi).

SSH: `useradd/userdel/passwd` tidak menyentuh proses lain → intrinsically
tanpa-gangguan. WS bridge stateless per-koneksi. SlowDNS/OVPN hanya
disentuh saat setup.

## 4. Verifikasi (di repo, tanpa root)

- `T1` builder protobuf: roundtrip tag/email/uuid/type-URL (`xray.*` +
  legacy `v2ray.core.*`), remove & stats — ALL-OK.
- `T2` `grpcCall` vs fake server h2c (header Huffman asli via lib `hpack`):
  sukses status 0 + error status 5/message — ALL-OK.
- `T3` demux: `/bebas123` → upstream terima `GET /vmess-ws`
  (rewrite OK), WS tak dikenal → 404, non-WS → web — ALL-OK.
