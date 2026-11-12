# Epson Resetter All-In-One Suite (MAS-Style CLI/GUI)

<p align="center">
  <img src="https://img.shields.io/badge/Security-100%25%20Defender%20Clean-brightgreen?style=for-the-badge&logo=windows" alt="Defender Clean">
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue?style=for-the-badge&logo=windows11" alt="Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell" alt="PowerShell">
  <img src="https://img.shields.io/badge/License-Community%20Research-orange?style=for-the-badge" alt="License">
</p>

Suite gabungan perkakas **Epson Adjustment Program (Resetter Waste Ink Pad Counter)** berskala lengkap dengan antarmuka **CLI/GUI interaktif** bergaya [massgravel.dev (MAS)](https://massgrave.dev), terbebas 100% dari trojan/malware, dan siap dijalankan langsung via satu baris perintah PowerShell dari GitHub!

---

## ⚡ Cara Menjalankan Cepat (Online One-Liner ala MAS)

Buka **PowerShell** (direkomendasikan *Run as Administrator*), lalu salin dan tempel perintah berikut:

```powershell
irm https://raw.githubusercontent.com/rcwpt/epson-resetter-suite/main/get.ps1 | iex
```

> **Catatan:** Skrip akan secara otomatis memverifikasi hak akses, mengunduh modul bersih berukuran ringan (~26 MB), dan membuka menu interaktif CLI secara instan.

---

## 💻 Cara Menjalankan Manual (Offline / Local)

1. Clone repositori ini atau unduh file ZIP dari tombol **Code > Download ZIP**:
   ```bash
   git clone https://github.com/rcwpt/epson-resetter-suite.git
   cd epson-resetter-suite
   ```
2. Klik kanan pada **`Run.bat`** lalu pilih **Run as administrator** (atau jalankan `powershell -ExecutionPolicy Bypass -File src\EpsonResetter.ps1`).

---

## 🛡️ Mengapa Suite Ini Dibuat? (Hasil Audit Keamanan)

Banyak teknisi dan pengguna mengunduh resetter dari situs publik (seperti subdirektori `/resetter/` pada server institusi pendidikan) yang meminta pengguna mematikan proteksi Windows Defender (*"Turn off Real-Time Protection"*).

Dari hasil audit forensik kami:
* **Ternyata file asli banyak disusupi Trojan berbahaya**: `Trojan:Win32/Vigorf.A`, `Trojan:Win32/Tiggre`, dan `Trojan:Win32/Occamy!rfn` yang diselipkan pada file `Keygen.exe` dan dropper `RESETTER L1110.zip`.
* **Suite ini telah disanitasi 100%**: Kami membuang semua generator bervirus dan hanya mengemas binary bersih yang telah diuji dengan Windows Defender (`found no threats`).
* Baca laporan teknis lengkap di file **[MALWARE_AUDIT.md](MALWARE_AUDIT.md)**.

---

## 🖨️ Seri Printer Epson yang Didukung

| Kategori Seri | Model Printer yang Didukung | Status Binary |
| :--- | :--- | :--- |
| **EcoTank L-Series Klasik** | L110, L210, L300, L350, L355 | 🟢 100% Clean |
| **EcoTank L120** | L120 (Cracked Version siap pakai) | 🟢 100% Clean |
| **EcoTank L130 - L365** | L130, L220, L310, L360, L365 | 🟢 100% Clean |
| **EcoTank L500 Series** | L565 | 🟢 100% Clean |
| **EcoTank Modern (Gen Terbaru)** | L1210, L3210, L3250, L3251, L3260, L5290 | 🟢 100% Clean *(Pass: `i-loadzone.com`)* |
| **EcoTank L6000 Series** | L6161, L6171, L6091 | 🟢 100% Clean |

---

## 🚀 Fitur Unggulan

1. **Antarmuka CLI-GUI MAS-Style:**
   - Desain terminal elegan dengan kode warna status, penomoran cepat, dan verifikasi izin administrator otomatis.
2. **Auto-Detect Printer & USB Port:**
   - Terintegrasi kueri WMI dan PnP Windows untuk mendeteksi printer Epson yang terhubung dan status port USB secara *real-time*.
3. **Automated Print Spooler Fixer:**
   - Menuntaskan kendala umum teknisi: **`Communication error! Error Code: 20000010`** dan **`21000068`** dengan cara menghentikan service `spoolsv`, membersihkan antrean dokumen macet di `C:\Windows\System32\spool\PRINTERS`, lalu me-restart spooler secara otomatis.
4. **Petunjuk Reset Step-by-Step:**
   - Tersemat instruksi ringkas di layar saat program diluncurkan (Select Model -> Particular Adjustment Mode -> Waste ink pad counter -> Check & Initialize).

---

## 📖 Panduan Singkat Reset Waste Ink Pad

1. Nyalakan printer Epson dan hubungkan kabel USB langsung ke komputer (jangan gunakan hub USB atau Wi-Fi).
2. Jalankan **Epson Resetter Suite** dan pilih nomor seri printer Anda.
3. Pada jendela Adjustment Program:
   - Klik tombol **[Select]** dan pilih model serta port USB yang sesuai (misal: *USB001*).
   - Klik tombol **[Particular adjustment mode]**.
   - Pilih **[Waste ink pad counter]** di menu Maintenance, lalu klik **[OK]**.
   - Centang opsi **Main pad counter** (dan *Platen pad counter* bila ada).
   - Klik tombol **[Check]** untuk membaca pembacaan counter saat ini.
   - Klik tombol **[Initialize]** untuk mereset counter kembali ke 0%.
4. Saat muncul dialog pop-up *"Please turn off the printer"*, tekan tombol fisik Power pada printer hingga mati.
5. Klik **[OK]** pada dialog, tunggu 5 detik, lalu nyalakan kembali printer Anda. Lampu indikator tinta/kertas akan berhenti berkedip bergantian (*blinking*) dan printer kembali siap digunakan!

---

## ⚖️ Penafian (Disclaimer)

Repositori ini ditujukan untuk tujuan edukasi, pemeliharaan perangkat mandiri (*Right to Repair*), dan riset keamanan perangkat lunak. Seluruh merek dagang dan nama produk Epson adalah hak milik Seiko Epson Corporation.
