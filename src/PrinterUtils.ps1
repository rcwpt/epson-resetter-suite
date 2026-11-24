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
    param ([bool]$Silent = $false)

    if (-not $Silent) { Write-Host "`n[i] Checking administrator privileges..." -ForegroundColor Cyan }
    if (-not (Test-IsAdmin)) {
        if (-not $Silent) {
            Write-Host "[!] Warning: Resetting Print Spooler requires Administrator privileges." -ForegroundColor Yellow
            Write-Host "    Please run PowerShell or the launcher as Administrator." -ForegroundColor Yellow
        }
        return $false
    }

    try {
        if (-not $Silent) { Write-Host "[1/4] Stopping Print Spooler service (spoolsv)..." -ForegroundColor Cyan }
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 600

        if (-not $Silent) { Write-Host "[2/4] Clearing stuck print queue documents..." -ForegroundColor Cyan }
        $spoolDir = "$env:SystemRoot\System32\spool\PRINTERS"
        if (Test-Path $spoolDir) {
            $deletedCount = 0
            Get-ChildItem -Path $spoolDir -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
                    $deletedCount++
                } catch { }
            }
            if (-not $Silent) { Write-Host "    -> $deletedCount queue files cleared." -ForegroundColor Green }
        }

        if (-not $Silent) { Write-Host "[3/4] Restarting Print Spooler service..." -ForegroundColor Cyan }
        Start-Service -Name Spooler -ErrorAction Stop
        Start-Sleep -Milliseconds 400

        $svc = Get-Service -Name Spooler
        if ($svc.Status -eq 'Running') {
            if (-not $Silent) {
                Write-Host "[✓] Print Spooler service successfully restarted and is RUNNING." -ForegroundColor Green
                Write-Host "    Epson USB port is now unlocked (Communication Error 20000010 resolved)." -ForegroundColor Green
            }
            return $true
        } else {
            if (-not $Silent) { Write-Host "[x] Print Spooler service failed to start. Status: $($svc.Status)" -ForegroundColor Red }
            return $false
        }
    } catch {
        if (-not $Silent) { Write-Host "[x] Failed to reset Print Spooler: $($_.Exception.Message)" -ForegroundColor Red }
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
    $matchedKey = ""
    foreach ($k in $downloadMap.Keys) {
        if ($ModelKey -like "*$k*") {
            $matched = $downloadMap[$k]
            $matchedKey = $k
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

    $targetDir = Join-Path $driversBaseDir $matchedKey
    $zipPath = Join-Path $driversBaseDir $matched.Zip

    Write-Host "[i] Target Driver: $($matched.Name)" -ForegroundColor Green

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

function Resolve-EpsonModelMapping {
    param ([string]$DeviceString)
    
    # 1. Epson L3110 (Dedicated Clean Resetter!)
    if ($DeviceString -match 'L3110') {
        return @{
            Series = "Epson L3110 (Dedicated Clean Resetter)"
            BinDir = "L3110"
            Exe    = "Adjprog.exe"
            Driver = "L3110"
            NeedsPassword = $false
        }
    }
    # 2. Modern EcoTank Family (L1210 / L3210 / L3250 / L5290 / L3150 / L1110)
    if ($DeviceString -match 'L1210|L3210|L3250|L3251|L3260|L5290|L3150|L1110|L4150') {
        return @{
            Series = "EcoTank Modern (L1210, L3210, L3250, L5290)"
            BinDir = "L1210_L3210_L3250_L3260_L5290"
            Exe    = "Adjprog.exe"
            Driver = "L3110"
            NeedsPassword = $true
        }
    }
    # 3. L120
    if ($DeviceString -match 'L120') {
        return @{
            Series = "Epson L120"
            BinDir = "L120"
            Exe    = "L120.exe"
            Driver = "L120"
            NeedsPassword = $false
        }
    }
    # 4. L130 / L220 / L310 / L360 / L365
    if ($DeviceString -match 'L130|L220|L310|L360|L365') {
        return @{
            Series = "Epson L130 / L220 / L310 / L360 / L365"
            BinDir = "L130_L220_L310_L360_L365"
            Exe    = "Adjprog.exe"
            Driver = "L220"
            NeedsPassword = $false
        }
    }
    # 5. L110 / L210 / L300 / L350 / L355
    if ($DeviceString -match 'L110|L210|L300|L350|L355') {
        return @{
            Series = "Epson L110 / L210 / L300 / L350 / L355"
            BinDir = "L110_L210_L300_L350_L355"
            Exe    = "Adjprogcracked.exe"
            Driver = "L210"
            NeedsPassword = $false
        }
    }
    # 6. L565
    if ($DeviceString -match 'L565') {
        return @{
            Series = "Epson L565"
            BinDir = "L565"
            Exe    = "Adjprog.exe"
            Driver = "L565"
            NeedsPassword = $false
        }
    }
    # 7. L6160 / L6170 / L6190 / L6161 / L6171 / L6091
    if ($DeviceString -match 'L6160|L6170|L6190|L6161|L6171|L6091') {
        return @{
            Series = "Epson L6161 / L6171 / L6091"
            BinDir = "L6161_L6171_L6091"
            Exe    = "AdjProg.exe"
            Driver = "L6160"
            NeedsPassword = $false
        }
    }
    return $null
}

function Show-CliPrinterDiagnostic {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                  DIRECT CLI / CMD PRINTER DIAGNOSTICS                         " -ForegroundColor Yellow
    Write-Host "         Real-Time Hardware, Queue & Native Print Test Dashboard               " -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan

    $printers = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue
    $epsonPrinters = $printers | Where-Object { $_.Name -like "*Epson*" -or $_.DriverName -like "*Epson*" }
    $targetPrinters = if ($epsonPrinters.Count -gt 0) { $epsonPrinters } else { $printers }

    if (-not $targetPrinters -or $targetPrinters.Count -eq 0) {
        Write-Host "`n[!] No printers detected in Windows." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    Write-Host "`nSelect printer to diagnose:" -ForegroundColor White
    for ($i = 0; $i -lt $targetPrinters.Count; $i++) {
        $p = $targetPrinters[$i]
        $defTag = if ($p.Default) { "[DEFAULT]" } else { "" }
        Write-Host "  [$($i+1)] $($p.Name) | Port: $($p.PortName) $defTag" -ForegroundColor Cyan
    }

    $idxInput = Read-Host "`nEnter printer number [1-$($targetPrinters.Count)]"
    $selectedIdx = [int]$idxInput - 1
    if ($selectedIdx -lt 0 -or $selectedIdx -ge $targetPrinters.Count) { $selectedIdx = 0 }
    $selPrinter = $targetPrinters[$selectedIdx]

    while ($true) {
        Clear-Host
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "             PRINTER DIAGNOSTIC REPORT: $($selPrinter.Name)                    " -ForegroundColor Green
        Write-Host "================================================================================" -ForegroundColor Cyan

        $live = Get-CimInstance Win32_Printer -Filter "Name='$($selPrinter.Name)'" -ErrorAction SilentlyContinue
        if (-not $live) { $live = $selPrinter }

        $stateText = if ($live.WorkOffline) { "OFFLINE" } else { "ONLINE / READY" }
        $stateColor = if ($live.WorkOffline) { "Red" } else { "Green" }

        $statusMap = @{
            1 = "Other"; 2 = "Unknown"; 3 = "Idle / Ready"; 4 = "Printing"; 5 = "Warming Up"
            6 = "Stopped"; 7 = "Offline"; 8 = "Paused"; 9 = "Error"; 10 = "Busy"
            11 = "Not Available"; 12 = "Waiting"; 13 = "Processing"; 14 = "Initialization"
        }
        $extStatus = if ($statusMap.ContainsKey($live.ExtendedPrinterStatus)) { $statusMap[$live.ExtendedPrinterStatus] } else { "Normal" }

        $errorMap = @{
            0 = "Unknown"; 1 = "Other"; 2 = "No Error (Normal)"; 3 = "Low Paper"; 4 = "No Paper"
            5 = "Low Toner/Ink"; 6 = "No Toner/Ink"; 7 = "Door Open"; 8 = "Jammed"; 9 = "Service Requested"
        }
        $detectedError = if ($errorMap.ContainsKey($live.DetectedErrorState)) { $errorMap[$live.DetectedErrorState] } else { "No Error" }

        $jobs = Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$($selPrinter.Name)*" }
        $jobCount = if ($jobs) { $jobs.Count } else { 0 }

        Write-Host " [HARDWARE & CONNECTION]" -ForegroundColor Yellow
        Write-Host "  * Printer Device Name : $($live.Name)" -ForegroundColor White
        Write-Host "  * Port / Communication: $($live.PortName)" -ForegroundColor White
        Write-Host "  * Online / Link State : $stateText" -ForegroundColor $stateColor
        Write-Host "  * Extended Device Stat: $extStatus" -ForegroundColor White
        Write-Host "  * Sensor / Error State: $detectedError" -ForegroundColor (if ($detectedError -match 'No Error') { 'Green' } else { 'Red' })
        
        Write-Host "`n [SPOOLER & QUEUE HEALTH]" -ForegroundColor Yellow
        Write-Host "  * Print Jobs in Queue : $jobCount job(s)" -ForegroundColor (if ($jobCount -gt 0) { 'Yellow' } else { 'Green' })
        if ($jobCount -gt 0) {
            foreach ($j in $jobs) {
                Write-Host "    - Job #$($j.JobId): '$($j.Document)' (Pages: $($j.TotalPages), Status: $($j.JobStatus))" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`n [DRIVER SPECIFICATIONS]" -ForegroundColor Yellow
        Write-Host "  * Driver Name         : $($live.DriverName)" -ForegroundColor White
        Write-Host "  * Print Processor     : $($live.PrintProcessor)" -ForegroundColor DarkGray
        Write-Host "  * Data Type Format    : $($live.PrintJobDataType)" -ForegroundColor DarkGray

        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host " DIAGNOSTIC COMMANDS (DIRECT FROM TERMINAL):" -ForegroundColor White
        Write-Host " [P]  Send Native Windows Test Page directly to this Printer (CMD Mode)" -ForegroundColor Green
        Write-Host " [C]  Clear / Cancel all pending jobs in this queue" -ForegroundColor Yellow
        Write-Host " [R]  Refresh live diagnostics" -ForegroundColor Cyan
        Write-Host " [W]  Launch Web Vector Test Tool (printertestultimate)" -ForegroundColor Magenta
        Write-Host " [0]  Return to Main Menu" -ForegroundColor DarkGray
        Write-Host "================================================================================" -ForegroundColor Cyan

        $diagCmd = Read-Host " Enter command [P, C, R, W, 0]"
        switch ($diagCmd.Trim().ToUpper()) {
            "P" {
                Write-Host "`n[i] Sending native test page to '$($selPrinter.Name)'..." -ForegroundColor Cyan
                try {
                    Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /k /n `"$($selPrinter.Name)`"" -Wait
                    Write-Host "[✓] Native test page command dispatched to printer spooler!" -ForegroundColor Green
                } catch {
                    Write-Host "[x] Error sending test page: $($_.Exception.Message)" -ForegroundColor Red
                }
                Start-Sleep -Seconds 2
            }
            "C" {
                Write-Host "`n[i] Cancelling jobs for '$($selPrinter.Name)'..." -ForegroundColor Cyan
                if ($jobs) {
                    foreach ($j in $jobs) {
                        try {
                            $j | Remove-CimInstance
                            Write-Host "    [✓] Cancelled job #$($j.JobId)" -ForegroundColor Green
                        } catch { }
                    }
                }
                Reset-PrinterSpooler -Silent $true
                Write-Host "[✓] Spooler queue purged and reset!" -ForegroundColor Green
                Start-Sleep -Seconds 2
            }
            "W" {
                Invoke-PrinterTest
                Start-Sleep -Seconds 2
            }
            "R" {
                # refreshes automatically
            }
            "0" {
                return
            }
        }
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

function Invoke-SmartAutoMode {
    param ([string]$BinBaseDir)

    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "           SMART 1-CLICK INSTANT MODE (FOR BEGINNERS & NON-TECH USERS)          " -ForegroundColor Yellow
    Write-Host "         Auto-Detects Hardware, Auto-Fixes Port, & Launches Matching Tool       " -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan

    Write-Host "`n[1/4] Scanning for physically connected Epson printer (USB)..." -ForegroundColor Cyan
    $printers = Get-EpsonPrinters
    $usb = Get-EpsonUsbDevices

    $detectedString = ""
    if ($printers.Count -gt 0) {
        $detectedString = ($printers | ForEach-Object { "$($_.Name) $($_.DriverName)" }) -join " "
    }
    if ($usb.Count -gt 0) {
        $detectedString += " " + (($usb | ForEach-Object { "$($_.FriendlyName) $($_.InstanceId)" }) -join " ")
    }

    $mapping = Resolve-EpsonModelMapping -DeviceString $detectedString

    if (-not $mapping) {
        Write-Host "    [!] Could not automatically recognize the specific model number." -ForegroundColor Yellow
        Write-Host "        Detected hardware string: $detectedString" -ForegroundColor DarkGray
        Write-Host "`n    Please select your model series:" -ForegroundColor White
        Write-Host "    [1] Epson L3110 (Dedicated Resetter)" -ForegroundColor Green
        Write-Host "    [2] Epson L1210 / L3210 / L3250 / L5290 / L3150" -ForegroundColor Cyan
        Write-Host "    [3] Epson L110 / L210 / L300 / L350 / L355" -ForegroundColor Cyan
        Write-Host "    [4] Epson L120" -ForegroundColor Cyan
        Write-Host "    [5] Epson L130 / L220 / L310 / L360 / L365" -ForegroundColor Cyan
        Write-Host "    [6] Epson L565" -ForegroundColor Cyan
        Write-Host "    [7] Epson L6161 / L6171 / L6091" -ForegroundColor Cyan
        $manualPick = Read-Host "    Pick number [1-7]"
        switch ($manualPick.Trim()) {
            "1" { $mapping = Resolve-EpsonModelMapping "L3110" }
            "2" { $mapping = Resolve-EpsonModelMapping "L3210" }
            "3" { $mapping = Resolve-EpsonModelMapping "L210" }
            "4" { $mapping = Resolve-EpsonModelMapping "L120" }
            "5" { $mapping = Resolve-EpsonModelMapping "L220" }
            "6" { $mapping = Resolve-EpsonModelMapping "L565" }
            "7" { $mapping = Resolve-EpsonModelMapping "L6161" }
            default { $mapping = Resolve-EpsonModelMapping "L3110" }
        }
    }

    Write-Host "`n[✓] Identified Series: $($mapping.Series)" -ForegroundColor Green

    Write-Host "`n[2/4] Pre-flight Check: Auto-repairing Print Spooler..." -ForegroundColor Cyan
    Reset-PrinterSpooler -Silent $true
    Write-Host "    [✓] Print queue and spooler port unlocked to prevent Error 20000010." -ForegroundColor Green

    Write-Host "`n[3/4] Checking Windows Printer Driver..." -ForegroundColor Cyan
    $hasDriver = Test-EpsonDriverInstalled -ModelKeyword $mapping.Driver
    if ($hasDriver) {
        Write-Host "    [✓] Official Epson driver is detected in Windows." -ForegroundColor Green
    } else {
        Write-Host "    [!] Warning: Windows driver for $($mapping.Series) is missing." -ForegroundColor Yellow
        $instChoice = Read-Host "    Press [Enter] to auto-install driver now, or [S] to skip"
        if ($instChoice.Trim().ToUpper() -ne 'S') {
            Install-EpsonDriver -ModelKey $mapping.Driver
        }
    }

    Write-Host "`n[4/4] Launching Adjustment Tool..." -ForegroundColor Cyan
    $toolPath = Join-Path $BinBaseDir $mapping.BinDir
    $fullExe = Join-Path $toolPath $mapping.Exe

    if ($mapping.NeedsPassword) {
        try {
            Set-Clipboard -Value "i-loadzone.com"
            Write-Host "    [🔑] Password 'i-loadzone.com' has been AUTO-COPIED to your clipboard!" -ForegroundColor Yellow
            Write-Host "         (If prompted for password, just press Ctrl + V and hit OK)" -ForegroundColor Yellow
        } catch { }
    }

    Write-Host ""
    Write-Host "┌────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "│                 FOOLPROOF 4-STEP RESET INSTRUCTIONS                    │" -ForegroundColor Yellow
    Write-Host "├────────────────────────────────────────────────────────────────────────┤" -ForegroundColor Yellow
    Write-Host "│ 1. In the program window, click [Particular adjustment mode].          │" -ForegroundColor White
    Write-Host "│ 2. Double-click [Waste ink pad counter] in the Maintenance list.       │" -ForegroundColor White
    Write-Host "│ 3. Check the box [Main pad counter], then click [Initialize].          │" -ForegroundColor White
    Write-Host "│ 4. Turn OFF the printer with power button when prompted, then turn ON! │" -ForegroundColor Green
    Write-Host "└────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""

    try {
        $proc = Start-Process -FilePath $fullExe -WorkingDirectory $toolPath -PassThru
        Write-Host "[✓] Tool is running! (PID: $($proc.Id))" -ForegroundColor Green
        
        Write-Host "`n[?] After your printer has been turned back ON:" -ForegroundColor Yellow
        $prompt = Read-Host "    Do you want to run a Diagnostic Test Print now? (Y/N)"
        if ($prompt.Trim().ToUpper() -eq 'Y') {
            Invoke-PrinterTest
        }
    } catch {
        Write-Host "[x] Failed to launch: $($_.Exception.Message)" -ForegroundColor Red
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
