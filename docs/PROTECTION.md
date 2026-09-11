# Proteksi Rilis (anti-crack) — panduan

Prinsip: **protektor mengerem, desain lisensi yang mengunci.**
Urutan wajib: desain benar dulu (sudah), baru virtualisasi fungsi lisensi.

## 1. Yang sudah ada di kode

- `src/license.cpp` fail-closed: tanpa bypass env/file, offline = ditolak,
  `selfCheck()` (root-owned, non-world-writable), tanpa pesan bocor cara bypass.
- Marker `ASV2_VMB("asv2-license")` / `ASV2_VME()` mengelilingi `licenseCheck()`.
  Build normal = no-op. Build rilis dengan SDK: `-DVMPROTECT_SDK` + `VMProtectSDK.h`.
- `make release`: hardening (`-fstack-protector-strong`, Fortify, PIE) + strip
  + `CHECKSUMS.sha256`.
- `hcr-setup`: verifikasi pin `hcr-server.sha256` bila berkas pin tersedia.

## 2. VMProtect (disarankan) vs VxLang (tidak)

- **VMProtect**: dukung Linux ELF + sistem lisensi RSA (serial terkunci
  nama/email/expiry, anti-keygen) + aktivasi online WebLM. Virtualisasi
  HANYA fungsi lisensi (`licenseCheck`, `selfCheck`) — jangan virtualisasi
  path per-koneksi (overhead ribuan kali). Proteksi dilakukan dari OS apapun
  ke target Linux. Catatan: berbayar (lisensi tahunan), dan tetap bisa
  di-devirtualisasi pakar dengan usaha besar.
- **VxLang**: fokus Windows; ELF masih beta (code-flattening saja, pilih fungsi
  manual, versi penuh via donasi). Tidak disarankan untuk rilis ini.

## 3. Checklist sebelum upload GitHub

1. `make release` dari tree bersih; catat `CHECKSUMS.sha256`.
2. Virtualisasi `asv2-license` via VMProtect; uji biner hasil di VPS bersih:
   lisensi valid jalan, IP tak terdaftar ditolak, expired ditolak.
3. Jangan upload: source (bila binary-only), `.pem/.key`, `api.conf`,
   `servers.list`, `bot.conf`, database, log, biner lama.
4. `hcr-server`: biner pihak ketiga (dev.epro). Upload ulang = risiko hak cipta
   + rantai pasok. Disarankan: JANGAN bundel; setup mengunduh dari sumber resmi
   + verifikasi `hcr-server.sha256`, atau minta izin tertulis.
5. Simpan 1 VPS kanari dengan versi rilis untuk deteksi dini crack beredar.

## 4. Batasan jujur

Tidak ada proteksi client-side yang absolut. Target realistis: crack butuh
mingguan dan skill tinggi (bukan `strings` + env var 5 menit), pembeli jujur
tidak terganggu, dan server lisensi tetap otoritas akhir.
