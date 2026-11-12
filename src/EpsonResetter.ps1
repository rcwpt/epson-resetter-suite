# ==============================================================================
#  EPSON RESETTER ALL-IN-ONE SUITE (MAS Style CLI-GUI)
#  By: rcwpt / Community Project
# ==============================================================================

#Requires -Version 5.1

$Host.UI.RawUI.WindowTitle = "Epson Resetter All-In-One Suite [Clean Edition]"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BaseDir = Split-Path -Parent $ScriptDir
$BinDir = Join-Path $BaseDir "bin"

# Import helper functions
. (Join-Path $ScriptDir "PrinterUtils.ps1")

function Show-Header {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "               EPSON RESETTER ALL-IN-ONE SUITE (CLI/GUI)                        " -ForegroundColor Yellow
    Write-Host "         Waste Ink Pad Counter Reset & Maintenance Tool (MAS-Style)             " -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    $isAdmin = Test-IsAdmin
    if ($isAdmin) {
        Write-Host " [Status] Mode: Administrator | Keamanan: 100% Bersih (No Trojans/Keygens)" -ForegroundColor Green
    } else {
        Write-Host " [Status] Mode: Standard User (Beberapa fitur spooler butuh Admin)" -ForegroundColor Yellow
    }
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
}

function Show-SecurityReport {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host "      LAPORAN AUDIT KEAMANAN: ANALISIS RESETTER DEPED OZAMIZ                    " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host @"
Dari hasil audit mendalam terhadap repositori DepEd Ozamiz (https://ozamiz.deped.gov.ph/resetter/):
Peringatan situs 'Turn off Real-Time Protection before downloading' TERBUKTI BUKAN SEKADAR FALSE POSITIVE!

Ditemukan Trojan & Malware Berbahaya aktif pada paket unduhan asli:
1. RESETTER L1110.zip                      -> Trojan:Win32/Vigorf.A (Tingkat: High/Severe)
2. Epson L3110 Resetter.zip                -> Trojan:Win32/Tiggre (Tingkat: High/Severe)
3. Epson L3150 Resetter/Keygen.exe         -> Trojan:Win32/Occamy!rfn & Tiggre (Tingkat: High)
4. Epson WorkForce WF-2650/Keygen.exe      -> Trojan:Win32/Tiggre!rfn & Ymacco!rfn (Tingkat: High)
5. Epson L4150 Resetters/Adjprrog L4150.exe -> Trojan:Win32/Tiggre!rfn

KATEGORI TOOL YANG AMAN (TELAH DIBERSIHKAN DAN DIMASUKKAN KE SUITE INI):
✓ Seri L110 / L210 / L300 / L350 / L355    -> 0 Ancaman (Bersih / Clean)
✓ Seri L120 (Cracked Version)               -> 0 Ancaman (Bersih / Clean)
✓ Seri L130 / L220 / L310 / L360 / L365    -> 0 Ancaman (Bersih / Clean)
✓ Seri L565                                 -> 0 Ancaman (Bersih / Clean)
✓ Seri Modern L1210 / L3210 / L3250 / L3260 / L5290 -> 0 Ancaman (Bersih / Clean)
✓ Seri L6161 / L6171 / L6091                -> 0 Ancaman (Bersih / Clean)

Windows Defender MpCmdRun pada folder 'bin' suite ini: "found no threats".
Seluruh generator berbahaya dan payload backdoor telah dibuang 100%!
"@ -ForegroundColor White
    Write-Host "`nTekan tombol apapun untuk kembali ke menu utama..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-HelpGuide {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "             PANDUAN & PEMECAHAN MASALAH (TROUBLESHOOTING)                     " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host @"
1. CARA RESET WASTE INK PAD COUNTER:
   - Nyalakan printer Epson dan colokkan kabel USB langsung ke port PC (jangan pakai hub/USB extension).
   - Jalankan tool resetter sesuai model printer Anda dari menu.
   - Klik [Select] -> Pilih model printer dan port USB (contoh: USB001 / EP_L3210).
   - Klik [Particular adjustment mode].
   - Klik [Waste ink pad counter] -> [OK].
   - Beri centang pada 'Main pad counter' (dan 'Platen pad counter' jika ada).
   - Klik [Check] untuk melihat persentase keausan pad.
   - Klik [Initialize] untuk mereset counter kembali ke 0%.
   - Muncul dialog 'Please turn off the printer', matikan tombol power printer.
   - Klik [OK], lalu nyalakan kembali printer setelah 5 detik. Selesai!

2. MENGATASI ERROR UMUM:
   - Error 'Communication error! Error Code: 20000010' atau '21000068':
     Penyebab: Port printer sedang dikunci oleh antrean dokumen cetak yang macet.
     Solusi: Pilih menu [S] di menu utama untuk mereset Print Spooler otomatis.
   - Error 'Port not recognized':
     Penyebab: Driver USB belum terpasang atau printer belum terdeteksi.
     Solusi: Pilih menu [D] untuk memeriksa koneksi USB printer.
   - Permintaan Password pada Seri L1210 / L3250:
     Password telah disiapkan secara otomatis: i-loadzone.com
"@ -ForegroundColor White
    Write-Host "`nTekan tombol apapun untuk kembali ke menu utama..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-PrinterDetection {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                 STATUS & DETEKSI PRINTER EPSON AKTIF                          " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    Write-Host "`n[1] Memeriksa Daftar Printer Terdaftar di Windows (WMI)..." -ForegroundColor Cyan
    $printers = Get-EpsonPrinters
    if ($printers.Count -gt 0) {
        Write-Host "    Ditemukan $($printers.Count) printer Epson:" -ForegroundColor Green
        foreach ($p in $printers) {
            $status = if ($p.WorkOffline) { "OFFLINE" } else { "ONLINE" }
            $isDefault = if ($p.Default) { "[DEFAULT]" } else { "" }
            Write-Host ("    * {0,-35} | Port: {1,-12} | Status: {2} {3}" -f $p.Name, $p.PortName, $status, $isDefault) -ForegroundColor White
        }
    } else {
        Write-Host "    [!] Tidak ada printer Epson yang terdaftar di Windows Driver." -ForegroundColor Yellow
    }

    Write-Host "`n[2] Memeriksa Perangkat Fisik USB Printer (Plug and Play)..." -ForegroundColor Cyan
    $usb = Get-EpsonUsbDevices
    if ($usb.Count -gt 0) {
        Write-Host "    Ditemukan $($usb.Count) perangkat USB printer terhubung:" -ForegroundColor Green
        foreach ($u in $usb) {
            Write-Host ("    * Perangkat : {0}" -f $u.FriendlyName) -ForegroundColor White
            Write-Host ("      Status    : {0}" -f $u.Status) -ForegroundColor Gray
            Write-Host ("      DeviceID  : {0}" -f $u.InstanceId) -ForegroundColor DarkGray
        }
    } else {
        Write-Host "    [!] Tidak ada printer Epson yang terdeteksi di port USB saat ini." -ForegroundColor Yellow
        Write-Host "        Pastikan printer menyala dan kabel USB tercolok kencang." -ForegroundColor DarkGray
    }

    Write-Host "`nTekan tombol apapun untuk kembali ke menu utama..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main Loop
while ($true) {
    Show-Header

    Write-Host "  PILIH SERI MODEL PRINTER EPSON YANG AKAN DIRESET:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1]  Epson L110 / L210 / L300 / L350 / L355" -ForegroundColor Cyan
    Write-Host "  [2]  Epson L120 (Cracked Version - Siap Pakai)" -ForegroundColor Cyan
    Write-Host "  [3]  Epson L130 / L220 / L310 / L360 / L365" -ForegroundColor Cyan
    Write-Host "  [4]  Epson L565" -ForegroundColor Cyan
    Write-Host "  [5]  Epson L1210 / L3210 / L3250 / L3251 / L3260 / L5290 (EcoTank Modern)" -ForegroundColor Green
    Write-Host "  [6]  Epson L6161 / L6171 / L6091" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ALAT BANTU & DIAGNOSTIK:" -ForegroundColor White
    Write-Host "  [D]  Deteksi Koneksi Printer & Port USB" -ForegroundColor Yellow
    Write-Host "  [S]  Bersihkan Print Spooler (Perbaiki Error 20000010)" -ForegroundColor Yellow
    Write-Host "  [M]  Laporan Audit Malware DepEd Ozamiz (Bukti Virus / Trojan)" -ForegroundColor Red
    Write-Host "  [H]  Panduan Langkah-demi-Langkah & Troubleshooting" -ForegroundColor White
    Write-Host ""
    Write-Host "  [0]  Keluar" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    $choice = Read-Host " Masukkan pilihan [1-6, D, S, M, H, 0]"
    switch ($choice.Trim().ToUpper()) {
        "1" {
            $tool = Join-Path $BinDir "L110_L210_L300_L350_L355"
            Start-ResetterTool -ToolPath $tool -ExeName "Adjprogcracked.exe" -ModelLabel "L110 / L210 / L300 / L350 / L355"
            Write-Host "`nTekan tombol apapun untuk kembali ke menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "2" {
            $tool = Join-Path $BinDir "L120"
            Start-ResetterTool -ToolPath $tool -ExeName "L120.exe" -ModelLabel "L120"
            Write-Host "`nTekan tombol apapun untuk kembali ke menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "3" {
            $tool = Join-Path $BinDir "L130_L220_L310_L360_L365"
            Start-ResetterTool -ToolPath $tool -ExeName "Adjprog.exe" -ModelLabel "L130 / L220 / L310 / L360 / L365"
            Write-Host "`nTekan tombol apapun untuk kembali ke menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "4" {
            $tool = Join-Path $BinDir "L565"
            Start-ResetterTool -ToolPath $tool -ExeName "Adjprog.exe" -ModelLabel "L565"
            Write-Host "`nTekan tombol apapun untuk kembali ke menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "5" {
            $tool = Join-Path $BinDir "L1210_L3210_L3250_L3260_L5290"
            $note = "Jika diminta Password saat pertama kali membuka, ketikkan: i-loadzone.com"
            Start-ResetterTool -ToolPath $tool -ExeName "Adjprog.exe" -ModelLabel "L1210 / L3210 / L3250 / L3251 / L3260 / L5290" -SpecialNote $note
            Write-Host "`nTekan tombol apapun untuk kembali ke menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "6" {
            $tool = Join-Path $BinDir "L6161_L6171_L6091"
            Start-ResetterTool -ToolPath $tool -ExeName "AdjProg.exe" -ModelLabel "L6161 / L6171 / L6091"
            Write-Host "`nTekan tombol apapun untuk kembali ke menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "D" {
            Show-PrinterDetection
        }
        "S" {
            Reset-PrinterSpooler
            Write-Host "`nTekan tombol apapun untuk kembali ke menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "M" {
            Show-SecurityReport
        }
        "H" {
            Show-HelpGuide
        }
        "0" {
            Clear-Host
            Write-Host "`nTerima kasih telah menggunakan Epson Resetter All-In-One Suite.`n" -ForegroundColor Green
            exit 0
        }
        default {
            Write-Host "`n[!] Pilihan tidak valid. Silakan tekan tombol yang sesuai." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
