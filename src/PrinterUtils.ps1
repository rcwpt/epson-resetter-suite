# Printer Utility Functions for Epson Resetter Suite
# Created with love by rcwpt | Instagram: @c.wijaya.t

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

function Test-EpsonDriverInstalled {
    param ([string]$ModelKeyword)
    try {
        $drivers = Get-CimInstance Win32_PrinterDriver -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like "*Epson*" -and ($_.Name -like "*$ModelKeyword*" -or [string]::IsNullOrWhiteSpace($ModelKeyword))
        }
        $printers = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object {
            $_.DriverName -like "*Epson*" -and ($_.DriverName -like "*$ModelKeyword*" -or $_.Name -like "*$ModelKeyword*")
        }
        return ($drivers.Count -gt 0 -or $printers.Count -gt 0)
    } catch {
        return $false
    }
}

function Reset-PrinterSpooler {
    Write-Host "`n[i] Checking administrator privileges..." -ForegroundColor Cyan
    if (-not (Test-IsAdmin)) {
        Write-Host "[!] Warning: Resetting Print Spooler requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "    Please run PowerShell or the launcher as Administrator." -ForegroundColor Yellow
        return $false
    }

    try {
        Write-Host "[1/4] Stopping Print Spooler service (spoolsv)..." -ForegroundColor Cyan
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 800

        Write-Host "[2/4] Clearing stuck print queue documents..." -ForegroundColor Cyan
        $spoolDir = "$env:SystemRoot\System32\spool\PRINTERS"
        if (Test-Path $spoolDir) {
            $deletedCount = 0
            Get-ChildItem -Path $spoolDir -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
                    $deletedCount++
                } catch {
                    Write-Host "    [!] Could not delete: $($_.Name)" -ForegroundColor DarkGray
                }
            }
            Write-Host "    -> $deletedCount queue files cleared." -ForegroundColor Green
        }

        Write-Host "[3/4] Restarting Print Spooler service..." -ForegroundColor Cyan
        Start-Service -Name Spooler -ErrorAction Stop
        Start-Sleep -Milliseconds 500

        Write-Host "[4/4] Verifying service status..." -ForegroundColor Cyan
        $svc = Get-Service -Name Spooler
        if ($svc.Status -eq 'Running') {
            Write-Host "[✓] Print Spooler service successfully restarted and is RUNNING." -ForegroundColor Green
            Write-Host "    Epson USB port is now unlocked (Communication Error 20000010 resolved)." -ForegroundColor Green
            return $true
        } else {
            Write-Host "[x] Print Spooler service failed to start. Status: $($svc.Status)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[x] Failed to reset Print Spooler: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-EpsonDriver {
    param ([string]$ModelKey)

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "               OFFICIAL EPSON DRIVER INSTALLER & DOWNLOADER                    " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan

    $driversBaseDir = Join-Path $env:LOCALAPPDATA "EpsonResetterSuite\drivers"
    if (-not (Test-Path $driversBaseDir)) {
        New-Item -ItemType Directory -Path $driversBaseDir -Force | Out-Null
    }

    $downloadMap = @{
        "L210" = @{
            Name = "Epson L210 Series (also supports L110/L300/L350/L355)"
            Url  = "https://ozamiz.deped.gov.ph/resetter/Driver%20Epson%20L210.zip"
            Zip  = "Driver_Epson_L210.zip"
            Pattern = "*x64*.exe"
        }
        "L220" = @{
            Name = "Epson L220 Series (also supports L130/L310/L360/L365)"
            Url  = "https://ozamiz.deped.gov.ph/resetter/Driver%20Epson%20L220.zip"
            Zip  = "Driver_Epson_L220.zip"
            Pattern = "Setup.exe"
        }
        "L3110" = @{
            Name = "Epson L3110 Series (also supports L1110/L3150)"
            Url  = "https://ozamiz.deped.gov.ph/resetter/Driver%20Epson%20L3110.zip"
            Zip  = "Driver_Epson_L3110.zip"
            Pattern = "*x64*.exe"
        }
    }

    # Match key
    $matched = $null
    foreach ($k in $downloadMap.Keys) {
        if ($ModelKey -like "*$k*") {
            $matched = $downloadMap[$k]
            break
        }
    }

    if (-not $matched) {
        Write-Host "[i] Dedicated direct package for '$ModelKey' is not bundled in default cache." -ForegroundColor Yellow
        Write-Host "    Redirecting to the official Epson Support & Driver Portal for $ModelKey..." -ForegroundColor Cyan
        $officialUrl = "https://www.google.com/search?q=epson+$ModelKey+official+driver+download"
        Start-Process $officialUrl
        Write-Host "[✓] Opened driver download search in your web browser." -ForegroundColor Green
        return $false
    }

    $targetDir = Join-Path $driversBaseDir $k
    $zipPath = Join-Path $driversBaseDir $matched.Zip

    Write-Host "[i] Target Driver: $($matched.Name)" -ForegroundColor Green

    # Check if already downloaded and extracted
    $installer = $null
    if (Test-Path $targetDir) {
        $found = Get-ChildItem -Path $targetDir -Recurse -Filter $matched.Pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $installer = $found.FullName }
    }

    if (-not $installer) {
        Write-Host "`n[1/3] Downloading official driver package (~85-92 MB)..." -ForegroundColor Cyan
        Write-Host "      Source: $($matched.Url)" -ForegroundColor DarkGray
        try {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($matched.Url, $zipPath)
            Write-Host "[✓] Download complete!" -ForegroundColor Green
        } catch {
            Write-Host "[x] Failed to download driver: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }

        Write-Host "[2/3] Extracting installer files..." -ForegroundColor Cyan
        try {
            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
            Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
            Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
            Write-Host "[✓] Extraction complete!" -ForegroundColor Green
        } catch {
            Write-Host "[x] Failed to extract archive: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }

        $found = Get-ChildItem -Path $targetDir -Recurse -Filter $matched.Pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $installer = $found.FullName
        }
    } else {
        Write-Host "[✓] Driver package is already cached locally." -ForegroundColor Green
    }

    if ($installer -and (Test-Path $installer)) {
        Write-Host "[3/3] Launching driver setup installer..." -ForegroundColor Cyan
        Write-Host "      Executing: $(Split-Path -Leaf $installer)" -ForegroundColor White
        Write-Host "      Please follow the on-screen installer wizard..." -ForegroundColor Yellow
        try {
            $proc = Start-Process -FilePath $installer -WorkingDirectory (Split-Path -Parent $installer) -Wait -PassThru
            Write-Host "[✓] Driver installer finished with exit code: $($proc.ExitCode)" -ForegroundColor Green
            Start-Sleep -Seconds 2
            return $true
        } catch {
            Write-Host "[x] Failed to execute installer: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "[x] Could not locate setup installer executable inside extracted folder." -ForegroundColor Red
        return $false
    }
}

function Invoke-PrinterTest {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  LAUNCHING ULTIMATE PRINTER TEST DIAGNOSTIC TOOL                              " -ForegroundColor Green
    Write-Host "  Repository: https://github.com/rcwpt/printertestultimate                      " -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "[i] Opening test page (CMYK solids, nozzle patterns, geometry alignment)..." -ForegroundColor Cyan
    
    $testUrl = "https://rcwpt.github.io/printertestultimate/?autoprint=1"
    try {
        Start-Process $testUrl
        Write-Host "[✓] Diagnostic tool launched in your default web browser!" -ForegroundColor Green
        Write-Host "    Direct Link: $testUrl" -ForegroundColor White
        Write-Host "    Short Link : https://tinyurl.com/rcwpt-print" -ForegroundColor Yellow
    } catch {
        Write-Host "[x] Failed to open browser. Please open manually: $testUrl" -ForegroundColor Red
    }
}

function Start-ResetterTool {
    param (
        [string]$ToolPath,
        [string]$ExeName,
        [string]$ModelLabel,
        [string]$DriverKey = "",
        [string]$SpecialNote = ""
    )

    $fullExe = Join-Path $ToolPath $ExeName
    if (-not (Test-Path $fullExe)) {
        Write-Host "`n[x] Executable file not found: $fullExe" -ForegroundColor Red
        return
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  CHECKING SYSTEM & PRINTER DRIVER STATUS: $ModelLabel" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan

    # Verify if driver is installed
    $driverInstalled = Test-EpsonDriverInstalled -ModelKeyword $DriverKey
    if ($driverInstalled) {
        Write-Host "[✓] Epson Printer Driver: INSTALLED & DETECTED" -ForegroundColor Green
    } else {
        Write-Host "[!] Epson Printer Driver: NOT DETECTED in Windows" -ForegroundColor Yellow
        Write-Host "    Notice: Without official USB drivers, the resetter may fail with:" -ForegroundColor DarkGray
        Write-Host "    'Communication Error 21000068' or 'Port not recognized'." -ForegroundColor DarkGray
        
        $dlChoice = Read-Host "`n[?] Would you like to automatically download & install the official driver now? (Y/N)"
        if ($dlChoice.Trim().ToUpper() -eq 'Y') {
            Install-EpsonDriver -ModelKey $DriverKey
        }
    }

    if ($SpecialNote) {
        Write-Host "`n[!] NOTE: $SpecialNote" -ForegroundColor Yellow
    }

    Write-Host "`n[i] Quick Reset Instructions (Waste Ink Pad Counter):" -ForegroundColor Cyan
    Write-Host "  1. Ensure printer is ON and connected directly via USB cable (avoid Wi-Fi)." -ForegroundColor White
    Write-Host "  2. Ensure the print queue is empty (no pending print jobs)." -ForegroundColor White
    Write-Host "  3. In the Adjustment Program window:" -ForegroundColor White
    Write-Host "     - Click [Select] -> Choose your Model and USB Port." -ForegroundColor Gray
    Write-Host "     - Click [Particular adjustment mode]." -ForegroundColor Gray
    Write-Host "     - Select [Waste ink pad counter] and click [OK]." -ForegroundColor Gray
    Write-Host "     - Check the box for [Main pad counter] (and [Platen pad counter] if present)." -ForegroundColor Gray
    Write-Host "     - Click [Check] to read current counter readings." -ForegroundColor Gray
    Write-Host "     - Click [Initialize] to reset counter to 0%." -ForegroundColor Yellow
    Write-Host "  4. When prompted 'Please turn off the printer', switch OFF the printer." -ForegroundColor White
    Write-Host "  5. Wait 5 seconds, then turn printer back ON. You are done!" -ForegroundColor Green
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Launching: $ExeName ..." -ForegroundColor Cyan

    try {
        $proc = Start-Process -FilePath $fullExe -WorkingDirectory $ToolPath -PassThru
        Write-Host "[✓] Program launched successfully! (PID: $($proc.Id))" -ForegroundColor Green
        
        Write-Host "`n[?] After turning your printer back ON and completing the reset:" -ForegroundColor Yellow
        $prompt = Read-Host "    Do you want to run a Diagnostic Test Print now? (Y/N)"
        if ($prompt.Trim().ToUpper() -eq 'Y') {
            Invoke-PrinterTest
        }
    } catch {
        Write-Host "[x] Failed to launch program: $($_.Exception.Message)" -ForegroundColor Red
    }
}
