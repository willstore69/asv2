# ASV2 — Sistem Quota & Limit Koneksi

Budget **unified per username**: satu angka di `/etc/william/limit-quota/<user>`
(bytes; `0` = unlimited) berlaku untuk **Xray + SSH digabung**.
`asv2 quota-status --user U` menampilkan pakai/limit/sisa.

## Quota Xray — restart-safe

- Tiap menit (`stats-sync`, juga di dalam `autoban`) traffic ditarik dari
  `StatsService/GetStats` (`user>>>email>>>traffic>>>up/down`) via gRPC native.
- Counter Xray **reset tiap restart** → `quota-state/x-<user>` menyimpan nilai
  counter terakhir; selisih negatif dianggap reset dan delta = nilai baru.
  Total akumulasi di `/etc/xray/usage-{up,down}link-tls/<user>` — **restart
  tidak lagi menghapus pemakaian** (bug lama).
- `renew` / periode baru → `quotaReset` (pakai + state + flag warn dibersihkan).
  `del` → `quotaPurge`.

## Quota SSH — direct + WS penuh (tanpa MITM)

Dua lapis yang saling melengkapi:

1. **Direct (OpenSSH/Dropbear)** — iptables owner-match: chain mangle
   `ASV2_OUT` (upload, `CONNMARK --set-mark`) + `ASV2_IN` (download, hanya
   hitung). Aturan dipasang saat `add-ssh`, dicabut saat `del-ssh`.
2. **SSH-WS (termasuk path generik!)** — demux `asv2-ws` menghitung byte
   per koneksi pada titik terminasi WS:
   - **Path personal** `/ssh-<user>` (dibuat otomatis tiap `add-ssh`,
     dihapus saat `del-ssh`): atribusi langsung & eksak. Tampilkan ke user
     agar quota WS-nya terhitung penuh.
   - **Path generik** (`/ssh-ws` dsb): korelasi soket→proses→user via
     `/proc` — eport sisi demux → entri server `127.0.0.1:22` di
     `/proc/net/tcp` → inode → PID sshd pemegang soket → UID (sudah setuid
     ke user pasca-auth) → username. Di-resolve berkala (butuh root di VPS,
     UID 0 ditolak). Byte sebelum auth ikut keatribusi (backfill).
   - Flush ke `usage-ssh/<user>` tiap 60 detik + saat koneksi tutup.

Counter diakumulasi restart-safe (pola sama seperti Xray).
**Keterbatasan jujur**: UDPGW/OVPN/SlowDNS (jalan sebagai root/nobody,
tanpa jejak user) tetap tak teratribusikan; Xray penuh via StatsService.

## Enforce quota

- `>=80%` → notif Telegram sekali per periode (`quota-warned/`).
- `>=100%` → ban sisi yang dimiliki user: Xray via API remove (sesi lain
  utuh), SSH via `passwd -l` + kill sesi. Notif menyertakan angka pakai/limit.

## Limit koneksi (limit device/IP)

Tunable `/etc/william/profile/limit.conf`:
`WINDOW_SEC=90` (jendela hitung Xray), `GRACE=1` (toleransi),
`STRIKES=2` (pelanggaran beruntun sebelum ban), `SSH_PORTS=22,109,143`.

- **SSH dihitung LIVE** (`ss -tnHp` + `ps`, bukan histori auth.log):
  sesi per user + IP unik. Melebihi `limit+GRACE` → bunuh **sesi termuda
  berlebih saja** (PID besar; sesi lama dipertahankan — beda dengan v1 yang
  `pkill -u` mematikan semua). Ban (`passwd -l`) hanya setelah STRIKES
  pelanggaran beruntun; patuh → strikes dihapus.
- **Xray**: IP unik dari `access.log` dalam WINDOW_SEC (parse kolom
  `from`/`email:`, format tanggal `/` maupun `-`, IP loopback/DNS
  dikecualikan). Melebihi batas → strikes; mencapai STRIKES → ban sementara
  via API (auto-unban seperti biasa, tanpa restart).
- Intip live: `asv2 conn` (juga `/api/conn`, bot `/conn`).

## Cron

```
* * * * * asv2 autoban     (sync traffic + enforce quota + limit + unban)
* * * * * asv2 stats-sync  (sync traffic saja; murah, API lokal)
*/30 * * * * asv2 delexp
```
