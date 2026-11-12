# ==============================================================================
#  EPSON RESETTER ALL-IN-ONE SUITE - WEB LAUNCHER (MAS-Style)
#  Created with love by rcwpt | Instagram: @c.wijaya.t
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
    Write-Host "[i] Requesting Administrator privileges to manage Print Spooler & direct USB ports..." -ForegroundColor Cyan
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/rcwpt/epson-resetter-suite/main/get.ps1 | iex }`""
        exit
    } catch {
        Write-Host "[!] Auto-elevation declined. Continuing in standard user mode..." -ForegroundColor Yellow
    }
}

$InstallDir = Join-Path $env:LOCALAPPDATA "EpsonResetterSuite"
$RepoZipUrl = "https://github.com/rcwpt/epson-resetter-suite/archive/refs/heads/main.zip"
$ZipTarget = Join-Path $env:TEMP "epson-resetter-suite.zip"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "              EPSON RESETTER ALL-IN-ONE SUITE - WEB INSTALLER                  " -ForegroundColor Yellow
Write-Host "             Created with love by rcwpt | Instagram: @c.wijaya.t                " -ForegroundColor Magenta
Write-Host "================================================================================" -ForegroundColor Cyan

# Check if suite already exists locally or update is needed
$MainScript = Join-Path $InstallDir "src\EpsonResetter.ps1"

if (-not (Test-Path $MainScript)) {
    Write-Host "[1/3] Downloading clean Epson Resetter Suite package from GitHub..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $RepoZipUrl -OutFile $ZipTarget -UseBasicParsing -TimeoutSec 60
        Write-Host "[✓] Download complete ($([math]::Round((Get-Item $ZipTarget).Length/1MB, 2)) MB)." -ForegroundColor Green
    } catch {
        Write-Host "[x] Failed to download archive from GitHub: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Write-Host "[2/3] Extracting package to $InstallDir ..." -ForegroundColor Cyan
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
        Write-Host "[✓] Package successfully installed!" -ForegroundColor Green
    } catch {
        Write-Host "[x] Failed to extract archive: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
} else {
    Write-Host "[✓] Epson Resetter Suite is already installed on local system." -ForegroundColor Green
}

Write-Host "[3/3] Launching interactive CLI/GUI..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 500

powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallDir "src\EpsonResetter.ps1")
