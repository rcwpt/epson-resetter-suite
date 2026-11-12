# Printer Utility Functions for Epson Resetter Suite

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-EpsonPrinters {
    try {
        $printers = Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like "*Epson*" -or $_.DriverName -like "*Epson*"
        }
        return $printers
    } catch {
        return @()
    }
}

function Get-EpsonUsbDevices {
    try {
        $usb = Get-PnpDevice -PresentOnly -Class "USB", "Printer" -ErrorAction SilentlyContinue | Where-Object {
            $_.FriendlyName -like "*Epson*" -or $_.FriendlyName -like "*USB Printing Support*" -or $_.InstanceId -like "*VID_04B8*"
        }
        return $usb
    } catch {
        return @()
    }
}

function Reset-PrinterSpooler {
    Write-Host "`n[i] Memeriksa hak akses administrator..." -ForegroundColor Cyan
    if (-not (Test-IsAdmin)) {
        Write-Host "[!] Perhatian: Mereset Print Spooler membutuhkan hak Administrator." -ForegroundColor Yellow
        Write-Host "    Silakan jalankan terminal / script sebagai Administrator." -ForegroundColor Yellow
        return $false
    }

    try {
        Write-Host "[1/4] Menghentikan layanan Print Spooler (spoolsv)..." -ForegroundColor Cyan
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 800

        Write-Host "[2/4] Membersihkan antrean dokumen (queue) yang macet..." -ForegroundColor Cyan
        $spoolDir = "$env:SystemRoot\System32\spool\PRINTERS"
        if (Test-Path $spoolDir) {
            $deletedCount = 0
            Get-ChildItem -Path $spoolDir -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
                    $deletedCount++
                } catch {
                    Write-Host "    [!] Tidak dapat menghapus: $($_.Name)" -ForegroundColor DarkGray
                }
            }
            Write-Host "    -> $deletedCount file antrean dibersihkan." -ForegroundColor Green
        }

        Write-Host "[3/4] Menjalankan kembali layanan Print Spooler..." -ForegroundColor Cyan
        Start-Service -Name Spooler -ErrorAction Stop
        Start-Sleep -Milliseconds 500

        Write-Host "[4/4] Verifikasi status layanan..." -ForegroundColor Cyan
        $svc = Get-Service -Name Spooler
        if ($svc.Status -eq 'Running') {
            Write-Host "[✓] Layanan Print Spooler berhasil direset dan berstatus RUNNING." -ForegroundColor Green
            Write-Host "    Port USB Epson kini bebas dari penguncian (Communication Error 20000010 teratasi)." -ForegroundColor Green
            return $true
        } else {
            Write-Host "[x] Layanan Print Spooler gagal berjalan. Status: $($svc.Status)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[x] Gagal mereset Print Spooler: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Start-ResetterTool {
    param (
        [string]$ToolPath,
        [string]$ExeName,
        [string]$ModelLabel,
        [string]$SpecialNote = ""
    )

    $fullExe = Join-Path $ToolPath $ExeName
    if (-not (Test-Path $fullExe)) {
        Write-Host "`n[x] File eksekusi tidak ditemukan: $fullExe" -ForegroundColor Red
        return
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  MENJALANKAN RESETTER EPSON: $ModelLabel" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    if ($SpecialNote) {
        Write-Host "[!] PENTING: $SpecialNote" -ForegroundColor Yellow
    }

    Write-Host "`n[i] Petunjuk Penggunaan Cepat (Waste Ink Pad Reset):" -ForegroundColor Cyan
    Write-Host "  1. Pastikan printer Epson NYALA dan TERHUBUNG kabel USB ke PC (hindari Wi-Fi)." -ForegroundColor White
    Write-Host "  2. Pastikan tidak ada dokumen yang sedang mencetak (Queue kosong)." -ForegroundColor White
    Write-Host "  3. Di jendela Adjustment Program:" -ForegroundColor White
    Write-Host "     - Klik tombol [Select] -> Pilih Model dan Port USB printer Anda." -ForegroundColor Gray
    Write-Host "     - Klik tombol [Particular adjustment mode]." -ForegroundColor Gray
    Write-Host "     - Pilih [Waste ink pad counter] lalu klik [OK]." -ForegroundColor Gray
    Write-Host "     - Centang kotak [Main pad counter] (dan [Platen pad counter] jika ada)." -ForegroundColor Gray
    Write-Host "     - Klik [Check] untuk membaca persentase counter." -ForegroundColor Gray
    Write-Host "     - Klik [Initialize] untuk mereset counter ke 0%." -ForegroundColor Yellow
    Write-Host "  4. Saat diminta 'Please turn off the printer', MATIKAN printer lewat tombol power." -ForegroundColor White
    Write-Host "  5. Tunggu 5 detik, lalu NYALAKAN kembali printer. Selesai!" -ForegroundColor Green
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Membuka: $ExeName ..." -ForegroundColor Cyan

    try {
        Start-Process -FilePath $fullExe -WorkingDirectory $ToolPath
        Write-Host "[✓] Program berhasil diluncurkan!" -ForegroundColor Green
    } catch {
        Write-Host "[x] Gagal menjalankan program: $($_.Exception.Message)" -ForegroundColor Red
    }
}
