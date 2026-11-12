# ==============================================================================
#  EPSON RESETTER ALL-IN-ONE SUITE - WEB LAUNCHER (MAS-Style)
#  Usage: irm https://raw.githubusercontent.com/rcwpt/epson-resetter-suite/main/get.ps1 | iex
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-Admin {
    $cur = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($cur)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Auto-elevate to Administrator if not already elevated
if (-not (Test-Admin)) {
    Write-Host "[i] Meminta hak akses Administrator untuk mengontrol Print Spooler & Port USB..." -ForegroundColor Cyan
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/rcwpt/epson-resetter-suite/main/get.ps1 | iex }`""
        exit
    } catch {
        Write-Host "[!] Gagal eskalasi otomatis. Melanjutkan dalam mode pengguna standar..." -ForegroundColor Yellow
    }
}

$InstallDir = Join-Path $env:LOCALAPPDATA "EpsonResetterSuite"
$RepoZipUrl = "https://github.com/rcwpt/epson-resetter-suite/archive/refs/heads/main.zip"
$ZipTarget = Join-Path $env:TEMP "epson-resetter-suite.zip"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "              EPSON RESETTER ALL-IN-ONE SUITE - WEB INSTALLER                  " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

# Check if suite already exists locally or update is needed
$MainScript = Join-Path $InstallDir "src\EpsonResetter.ps1"

if (-not (Test-Path $MainScript)) {
    Write-Host "[1/3] Mengunduh paket Epson Resetter Suite dari GitHub..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $RepoZipUrl -OutFile $ZipTarget -UseBasicParsing -TimeoutSec 60
        Write-Host "[✓] Unduhan selesai ($([math]::Round((Get-Item $ZipTarget).Length/1MB, 2)) MB)." -ForegroundColor Green
    } catch {
        Write-Host "[x] Gagal mengunduh arsip dari GitHub: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Write-Host "[2/3] Mengekstrak paket ke $InstallDir ..." -ForegroundColor Cyan
    try {
        if (Test-Path $InstallDir) { Remove-Item -Path $InstallDir -Recurse -Force }
        $tempExtract = Join-Path $env:TEMP "epson_extract_temp"
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force }
        
        Expand-Archive -Path $ZipTarget -DestinationPath $tempExtract -Force
        $innerFolder = Join-Path $tempExtract "epson-resetter-suite-main"
        if (Test-Path $innerFolder) {
            Move-Item -Path $innerFolder -Destination $InstallDir -Force
        } else {
            Move-Item -Path $tempExtract -Destination $InstallDir -Force
        }
        Remove-Item -Path $ZipTarget -Force -ErrorAction SilentlyContinue
        Write-Host "[✓] Paket berhasil dipasang!" -ForegroundColor Green
    } catch {
        Write-Host "[x] Gagal mengekstrak: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
} else {
    Write-Host "[✓] Paket Epson Resetter Suite sudah terpasang di sistem lokal." -ForegroundColor Green
}

Write-Host "[3/3] Meluncurkan antarmuka CLI/GUI..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 500

powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallDir "src\EpsonResetter.ps1")
