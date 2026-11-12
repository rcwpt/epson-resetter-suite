# ==============================================================================
#  EPSON RESETTER SUITE - WEB LAUNCHER
#  Created with love by rcwpt | Instagram: @c.wijaya.t
#  Usage: irm tinyurl.com/rcwpt-epson | iex
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-Admin {
    $cur = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($cur)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Auto-elevate to Administrator if not already elevated
if (-not (Test-Admin)) {
    Write-Host "[i] Requesting Administrator privileges to manage Print Spooler & USB ports..." -ForegroundColor Cyan
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm tinyurl.com/rcwpt-epson | iex }`""
        exit
    } catch {
        Write-Host "[!] Auto-elevation declined. Continuing in standard user mode..." -ForegroundColor Yellow
    }
}

$InstallDir = Join-Path $env:LOCALAPPDATA "EpsonResetterSuite"
$RepoZipUrl = "https://github.com/rcwpt/epson-resetter-suite/archive/refs/heads/main.zip"
$ZipTarget = Join-Path $env:TEMP "epson-resetter-suite.zip"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                             EPSON RESETTER SUITE                               " -ForegroundColor Yellow
Write-Host "             Created with love by rcwpt | Instagram: @c.wijaya.t                " -ForegroundColor Magenta
Write-Host "================================================================================" -ForegroundColor Cyan

# Always fetch the latest version to ensure immediate updates
Write-Host "[1/2] Fetching the latest clean package from GitHub..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $ZipTarget -UseBasicParsing -TimeoutSec 60
    Write-Host "[✓] Download complete ($([math]::Round((Get-Item $ZipTarget).Length/1MB, 2)) MB)." -ForegroundColor Green
} catch {
    Write-Host "[x] Failed to download package from GitHub: $($_.Exception.Message)" -ForegroundColor Red
    return
}

Write-Host "[2/2] Updating package files in $InstallDir ..." -ForegroundColor Cyan
try {
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $tempExtract = Join-Path $env:TEMP "epson_extract_temp"
    if (Test-Path $tempExtract) {
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Expand-Archive -Path $ZipTarget -DestinationPath $tempExtract -Force
    $innerFolder = Join-Path $tempExtract "epson-resetter-suite-main"
    if (Test-Path $innerFolder) {
        Move-Item -Path $innerFolder -Destination $InstallDir -Force
    } else {
        Move-Item -Path $tempExtract -Destination $InstallDir -Force
    }
    Remove-Item -Path $ZipTarget -Force -ErrorAction SilentlyContinue
    Write-Host "[✓] Package successfully updated!" -ForegroundColor Green
} catch {
    Write-Host "[!] Notice during update: $($_.Exception.Message)" -ForegroundColor DarkGray
}

Write-Host "`nLaunching suite interface..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 400

powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallDir "src\EpsonResetter.ps1")
