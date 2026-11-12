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

function Start-ResetterTool {
    param (
        [string]$ToolPath,
        [string]$ExeName,
        [string]$ModelLabel,
        [string]$SpecialNote = ""
    )

    $fullExe = Join-Path $ToolPath $ExeName
    if (-not (Test-Path $fullExe)) {
        Write-Host "`n[x] Executable file not found: $fullExe" -ForegroundColor Red
        return
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  LAUNCHING EPSON RESETTER: $ModelLabel" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    if ($SpecialNote) {
        Write-Host "[!] NOTE: $SpecialNote" -ForegroundColor Yellow
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
        Start-Process -FilePath $fullExe -WorkingDirectory $ToolPath
        Write-Host "[✓] Program launched successfully!" -ForegroundColor Green
    } catch {
        Write-Host "[x] Failed to launch program: $($_.Exception.Message)" -ForegroundColor Red
    }
}
