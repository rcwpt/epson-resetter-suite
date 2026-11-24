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
                Write-Host "[OK] Print Spooler service successfully restarted and is RUNNING." -ForegroundColor Green
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
    Write-Host "                EPSON OFFICIAL DRIVER INSTALLER & REPAIR                       " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan

    $driverCatalog = @{
        "L210" = @{
            Name = "Epson L210 Series Driver (32/64-bit)"
            Url  = "https://download.ebz.epson.net/dsc/du/02/DriverDownloadInfo.do?LG2=EN&CN2=SG&CTI=4&PRN=L210&OSC=WS"
            Direct = "https://download3.ebz.epson.net/dsc/f/03/00/01/54/66/8bc14f86ce9787ff3f8eb738f6d7eb80a4ff0a18/L210_x64_153Us.exe"
        }
        "L220" = @{
            Name = "Epson L220 Series Driver (32/64-bit)"
            Url  = "https://download.ebz.epson.net/dsc/du/02/DriverDownloadInfo.do?LG2=EN&CN2=SG&CTI=4&PRN=L220&OSC=WS"
            Direct = "https://download3.ebz.epson.net/dsc/f/03/00/03/61/88/24858b29759c8646b9be51ba47c94fafe6480b5b/L220_x64_222Us.exe"
        }
        "L3110" = @{
            Name = "Epson L3110 Series Driver (32/64-bit)"
            Url  = "https://download.ebz.epson.net/dsc/du/02/DriverDownloadInfo.do?LG2=EN&CN2=SG&CTI=4&PRN=L3110&OSC=WS"
            Direct = "https://download3.ebz.epson.net/dsc/f/03/00/08/96/66/12ee499d69e06180fc4ef2d9c02500c5cbcfb940/L3110_x64_26101Us.exe"
        }
    }

    $matched = $null
    foreach ($k in $driverCatalog.Keys) {
        if ($ModelKey -like "*$k*") {
            $matched = $driverCatalog[$k]
            break
        }
    }

    if ($matched) {
        Write-Host "[i] Target Driver Identified: $($matched.Name)" -ForegroundColor Green
        $targetExe = Join-Path $env:TEMP ("Epson_" + $ModelKey + "_Driver.exe")
        
        Write-Host "[1/3] Downloading official driver from Epson CDN..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $matched.Direct -OutFile $targetExe -UseBasicParsing -TimeoutSec 60
            Write-Host "[OK] Download complete ($([math]::Round((Get-Item $targetExe).Length/1MB, 2)) MB)." -ForegroundColor Green

            Write-Host "[2/3] Launching driver setup installer..." -ForegroundColor Cyan
            Write-Host "      Please follow the Epson on-screen wizard to finish driver setup." -ForegroundColor White
            Start-Process -FilePath $targetExe -Wait
            
            Write-Host "[3/3] Verifying driver installation in Windows..." -ForegroundColor Cyan
            Start-Sleep -Seconds 2
            if (Test-EpsonDriverInstalled -ModelKeyword $ModelKey) {
                Write-Host "[OK] Driver installed and active!" -ForegroundColor Green
            } else {
                Write-Host "[!] Setup closed. Please restart launcher once driver configuration finishes." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "[!] Direct CDN download failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[i] Opening official Epson driver download page in your browser..." -ForegroundColor Cyan
            Start-Process $matched.Url
        }
    } else {
        Write-Host "[!] Specific direct package not cataloged for model key: '$ModelKey'." -ForegroundColor Yellow
        Write-Host "[i] Opening official Epson Support & Driver Portal in your browser..." -ForegroundColor Cyan
        $searchUrl = "https://www.google.com/search?q=" + [System.Uri]::EscapeDataString("Epson $ModelKey driver download official")
        Start-Process $searchUrl
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

# ==============================================================================
#  AUTOMATED PRINTER REPAIR & PORT CONSOLIDATION TOOLS
# ==============================================================================

function Show-PrinterSummaryTable {
    param ([string]$FilterPattern = "*")
    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue | Where-Object {
            if ($FilterPattern -eq "*") { $true } else { $_.Name -like $FilterPattern -or $_.DriverName -like $FilterPattern }
        }
        if (-not $printers -or $printers.Count -eq 0) {
            $printers = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object {
                if ($FilterPattern -eq "*") { $true } else { $_.Name -like $FilterPattern -or $_.DriverName -like $FilterPattern }
            }
        }
        if ($printers) {
            Write-Host "`n  Current Registered Printers Status:" -ForegroundColor Cyan
            $table = $printers | Select-Object Name, PortName, Default, @{Name="Status";Expression={if ($_.WorkOffline) { "Offline" } else { "Online/Ready" }}}
            $table | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor White }
        }
    } catch {
        Write-Host "[!] Could not fetch printer table: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

function Set-EpsonDefaultPrinter {
    param ([string]$PrinterName)
    try {
        Write-Host "`n[1/2] Disabling Windows automatic default printer management (LegacyDefaultPrinterMode = 1)..." -ForegroundColor Cyan
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name "LegacyDefaultPrinterMode" -Value 1 -Force -ErrorAction SilentlyContinue

        Write-Host "[2/2] Setting '$PrinterName' as Windows default printer..." -ForegroundColor Cyan
        $target = Get-CimInstance -ClassName Win32_Printer -Filter "Name='$PrinterName'" -ErrorAction SilentlyContinue
        if ($target) {
            $res = $target | Invoke-CimMethod -MethodName SetDefaultPrinter
            if ($res.ReturnValue -eq 0) {
                Write-Host "[OK] '$PrinterName' is now the Default Printer!" -ForegroundColor Green
            } else {
                (New-Object -ComObject WScript.Network).SetDefaultPrinter($PrinterName)
                Write-Host "[OK] '$PrinterName' set as Default Printer (COM fallback)!" -ForegroundColor Green
            }
        } else {
            (New-Object -ComObject WScript.Network).SetDefaultPrinter($PrinterName)
            Write-Host "[OK] '$PrinterName' set as Default Printer!" -ForegroundColor Green
        }
        
        Show-PrinterSummaryTable -FilterPattern "*$($PrinterName.Split(' ')[0..1] -join ' ')*"
        return $true
    } catch {
        Write-Host "[x] Error setting default printer: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Consolidate-EpsonPrinterCopies {
    param (
        [string]$PrimaryName,
        [string]$TargetPortName
    )

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "         CONSOLIDATING DUPLICATE PRINTERS & REASSIGNING ACTIVE PORT            " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan

    $isAdmin = Test-IsAdmin
    if (-not $isAdmin) {
        Write-Host "[!] Administrator privileges required to remove duplicate drivers and reassign ports." -ForegroundColor Yellow
        Write-Host "    Please launch PowerShell as Administrator for full consolidation." -ForegroundColor Yellow
        return $false
    }

    $allPrinters = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue
    $baseName = $PrimaryName -replace '\s*\((Copy|Salinan)\s*\d+\)', ''
    $escapedBase = [regex]::Escape($baseName)
    $duplicates = $allPrinters | Where-Object { $_.Name -match "^$escapedBase\s*\((Copy|Salinan)\s*\d+\)" }

    if (-not $TargetPortName -and $duplicates) {
        $activeDup = $duplicates | Where-Object { $_.PortName -match "USB" } | Select-Object -First 1
        if ($activeDup) { $TargetPortName = $activeDup.PortName }
    }
    if (-not $TargetPortName) {
        $TargetPortName = "USB001"
    }

    Write-Host "`n[1/5] Removing duplicate copy instances of '$baseName'..." -ForegroundColor Cyan
    if ($duplicates) {
        foreach ($d in $duplicates) {
            try {
                Remove-Printer -Name $d.Name -ErrorAction Stop
                Write-Host "    [OK] Removed duplicate driver: '$($d.Name)'" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Notice removing '$($d.Name)': $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Host "    [i] No extra duplicate copies found to delete." -ForegroundColor DarkGray
    }

    Write-Host "[2/5] Reassigning primary driver '$baseName' to active Port '$TargetPortName'..." -ForegroundColor Cyan
    try {
        Set-Printer -Name $baseName -PortName $TargetPortName -ErrorAction Stop
        Write-Host "    [OK] Port successfully remapped to '$TargetPortName'!" -ForegroundColor Green
    } catch {
        Write-Host "    [x] Set-Printer port change warning: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "[3/5] Setting '$baseName' as Windows Default Printer..." -ForegroundColor Cyan
    Set-EpsonDefaultPrinter -PrinterName $baseName | Out-Null

    Write-Host "[4/5] Restarting Print Spooler service to refresh Epson Status Monitor..." -ForegroundColor Cyan
    Reset-PrinterSpooler -Silent $true | Out-Null
    Write-Host "    [OK] Print Spooler refreshed and active." -ForegroundColor Green

    Write-Host "[5/5] Final Verification:" -ForegroundColor Cyan
    Show-PrinterSummaryTable -FilterPattern "*$($baseName.Split(' ')[0..1] -join ' ')*"
    return $true
}

function Set-PrinterOnline {
    param ([string]$PrinterName)
    try {
        Write-Host "`n[i] Toggling '$PrinterName' online..." -ForegroundColor Cyan
        $wmi = [wmi]"\\.\root\cimv2:Win32_Printer.DeviceID='$PrinterName'"
        if ($wmi) {
            $wmi.WorkOffline = $false
            $wmi.Put() | Out-Null
            Write-Host "[OK] '$PrinterName' set to ONLINE!" -ForegroundColor Green
        }
    } catch {
        Write-Host "[!] Could not toggle offline status: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Invoke-PrinterIssueRepairWizard {
    param ([string]$TargetPrinterName = $null)

    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                    AUTOMATED PRINTER REPAIR WIZARD                            " -ForegroundColor Yellow
    Write-Host "        Fix Duplicate Driver Copies, Port Mismatch (USB001 vs USB005) & Offline " -ForegroundColor White
    Write-Host "================================================================================" -ForegroundColor Cyan

    $allPrinters = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue
    $epsonPrinters = $allPrinters | Where-Object { $_.Name -like "*Epson*" -or $_.DriverName -like "*Epson*" }
    if (-not $epsonPrinters -or $epsonPrinters.Count -eq 0) {
        $epsonPrinters = $allPrinters
    }

    if (-not $epsonPrinters) {
        Write-Host "`n[!] No printers detected in Windows." -ForegroundColor Yellow
        Write-Host "`nPress any key to return to menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # Find issues across installed printers
    $issues = @()
    $duplicateGroups = @{}

    foreach ($p in $epsonPrinters) {
        $base = $p.Name -replace '\s*\((Copy|Salinan)\s*\d+\)', ''
        if (-not $duplicateGroups.ContainsKey($base)) {
            $duplicateGroups[$base] = @()
        }
        $duplicateGroups[$base] += $p
    }

    foreach ($base in $duplicateGroups.Keys) {
        $group = $duplicateGroups[$base]
        if ($group.Count -gt 1) {
            $names = ($group | ForEach-Object { "$($_.Name) [Port: $($_.PortName)]" }) -join ", "
            $issues += @{
                Type = "DUPLICATE_COPIES"
                Base = $base
                Printers = $group
                Desc = "Duplicate printer drivers exist: $names"
            }
        }
    }

    foreach ($p in $epsonPrinters) {
        if ($p.WorkOffline) {
            $issues += @{
                Type = "OFFLINE"
                Printer = $p
                Desc = "Printer '$($p.Name)' is marked OFFLINE (communication blocked)."
            }
        }
    }

    $jobs = Get-CimInstance Win32_PrintJob -ErrorAction SilentlyContinue
    if ($jobs -and $jobs.Count -gt 0) {
        $issues += @{
            Type = "STUCK_QUEUE"
            Jobs = $jobs
            Desc = "$($jobs.Count) print job(s) stuck in spooler queue (causing Error 20000010)."
        }
    }

    $legacyMode = (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name "LegacyDefaultPrinterMode" -ErrorAction SilentlyContinue).LegacyDefaultPrinterMode
    if ($legacyMode -ne 1) {
        $issues += @{
            Type = "AUTO_DEFAULT"
            Desc = "Windows Automatic Default Printer management is enabled (may switch ports unexpectedly)."
        }
    }

    Write-Host "`n[ANALYSIS OF PRINTER SYSTEM HEALTH]" -ForegroundColor Yellow
    if ($issues.Count -eq 0) {
        Write-Host "  [OK] No critical printer driver or duplicate copy conflicts detected!" -ForegroundColor Green
    } else {
        Write-Host "  [!] Found $($issues.Count) issue(s) that can cause 'Port not recognized' or Error 20000010:" -ForegroundColor Yellow
        $num = 1
        foreach ($iss in $issues) {
            Write-Host "    $num. $($iss.Desc)" -ForegroundColor Red
            $num++
        }
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host " AUTOMATED REPAIR ACTIONS (1-CLICK CMD FIX):" -ForegroundColor White
    Write-Host " [1]  Option 1: Set Active Copy (e.g. Copy 1) as Default Printer (Fast & Safe)" -ForegroundColor Cyan
    Write-Host " [2]  Option 2: Consolidate & Clean Port (Removes Duplicate Copy, Remaps Port)" -ForegroundColor Green
    Write-Host " [3]  Toggle Offline Printers back to ONLINE" -ForegroundColor Yellow
    Write-Host " [4]  Reset Print Spooler & Clear Stuck Print Queues" -ForegroundColor Yellow
    Write-Host " [5]  Disable Windows Auto-Default Printer Mode (Fix Permanent Selection)" -ForegroundColor Cyan
    Write-Host " [0]  Return to Main Menu" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan

    $repChoice = Read-Host " Enter repair option [1-5, 0]"
    switch ($repChoice.Trim()) {
        "1" {
            Write-Host "`nSelect printer to set as Default:" -ForegroundColor White
            for ($i = 0; $i -lt $epsonPrinters.Count; $i++) {
                $p = $epsonPrinters[$i]
                $defTag = if ($p.Default) { "[CURRENT DEFAULT]" } else { "" }
                Write-Host "  [$($i+1)] $($p.Name) | Port: $($p.PortName) $defTag" -ForegroundColor Cyan
            }
            $pPick = Read-Host "`nEnter number [1-$($epsonPrinters.Count)]"
            $pIdx = [int]$pPick - 1
            if ($pIdx -ge 0 -and $pIdx -lt $epsonPrinters.Count) {
                Set-EpsonDefaultPrinter -PrinterName $epsonPrinters[$pIdx].Name
            }
        }
        "2" {
            $dupGroupList = @($duplicateGroups.Keys | Where-Object { $duplicateGroups[$_].Count -gt 1 })
            if ($dupGroupList.Count -eq 0) {
                Write-Host "`n[i] No duplicate copy groups detected. Select printer to reassign port:" -ForegroundColor Yellow
                for ($i = 0; $i -lt $epsonPrinters.Count; $i++) {
                    Write-Host "  [$($i+1)] $($epsonPrinters[$i].Name) | Port: $($epsonPrinters[$i].PortName)" -ForegroundColor Cyan
                }
                $pPick = Read-Host "`nEnter number [1-$($epsonPrinters.Count)]"
                $pIdx = [int]$pPick - 1
                if ($pIdx -ge 0 -and $pIdx -lt $epsonPrinters.Count) {
                    $targetP = $epsonPrinters[$pIdx]
                    $newPort = Read-Host "Enter active USB port (e.g. USB005, USB001) [Current: $($targetP.PortName)]"
                    if (-not [string]::IsNullOrWhiteSpace($newPort)) {
                        Consolidate-EpsonPrinterCopies -PrimaryName $targetP.Name -TargetPortName $newPort.Trim()
                    }
                }
            } else {
                Write-Host "`nDetected duplicate printer family:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $dupGroupList.Count; $i++) {
                    Write-Host "  [$($i+1)] $($dupGroupList[$i]) ($($duplicateGroups[$dupGroupList[$i]].Count) copies)" -ForegroundColor Green
                }
                $gPick = Read-Host "`nEnter number [1-$($dupGroupList.Count)]"
                $gIdx = [int]$gPick - 1
                if ($gIdx -lt 0 -or $gIdx -ge $dupGroupList.Count) { $gIdx = 0 }
                $targetFamily = $dupGroupList[$gIdx]
                $members = $duplicateGroups[$targetFamily]
                
                $usbMember = $members | Where-Object { $_.Name -match '\(Copy' -and $_.PortName -match 'USB' } | Select-Object -First 1
                $suggestedPort = if ($usbMember) { $usbMember.PortName } else { ($members | Select-Object -First 1).PortName }

                Write-Host "`n[i] Detected active copy on Port: $suggestedPort" -ForegroundColor Cyan
                $portInput = Read-Host "Confirm target port for '$targetFamily' [Press ENTER for $suggestedPort]"
                $finalPort = if ([string]::IsNullOrWhiteSpace($portInput)) { $suggestedPort } else { $portInput.Trim() }

                Consolidate-EpsonPrinterCopies -PrimaryName $targetFamily -TargetPortName $finalPort
            }
        }
        "3" {
            foreach ($p in $epsonPrinters) {
                if ($p.WorkOffline) {
                    Set-PrinterOnline -PrinterName $p.Name
                }
            }
            Show-PrinterSummaryTable
        }
        "4" {
            Reset-PrinterSpooler
        }
        "5" {
            Write-Host "`n[i] Setting LegacyDefaultPrinterMode = 1..." -ForegroundColor Cyan
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name "LegacyDefaultPrinterMode" -Value 1 -Force
            Write-Host "[OK] Windows Automatic Default Printer management has been DISABLED permanently." -ForegroundColor Green
        }
        "0" { return }
    }

    Write-Host "`nPress any key to return to menu..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
        $offTag = if ($p.WorkOffline) { "[OFFLINE]" } else { "" }
        Write-Host "  [$($i+1)] $($p.Name) | Port: $($p.PortName) $defTag $offTag" -ForegroundColor Cyan
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

        # Check duplicate copies of this model
        $allPrn = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue
        $baseName = $selPrinter.Name -replace '\s*\((Copy|Salinan)\s*\d+\)', ''
        $escapedBase = [regex]::Escape($baseName)
        $duplicates = $allPrn | Where-Object { $_.Name -match "^$escapedBase\s*\((Copy|Salinan)\s*\d+\)" }
        $hasDuplicates = ($duplicates.Count -gt 0)

        Write-Host " [HARDWARE & CONNECTION]" -ForegroundColor Yellow
        Write-Host "  * Printer Device Name : $($live.Name)" -ForegroundColor White
        Write-Host "  * Port / Communication: $($live.PortName)" -ForegroundColor White
        Write-Host "  * Online / Link State : $stateText" -ForegroundColor $stateColor
        Write-Host "  * Default Printer     : $(if ($live.Default) { 'YES [Default]' } else { 'NO' })" -ForegroundColor (if ($live.Default) { 'Green' } else { 'Yellow' })
        Write-Host "  * Extended Device Stat: $extStatus" -ForegroundColor White
        Write-Host "  * Sensor / Error State: $detectedError" -ForegroundColor (if ($detectedError -match 'No Error') { 'Green' } else { 'Red' })

        if ($hasDuplicates) {
            Write-Host "`n [!] ALERT: DUPLICATE DRIVER COPIES DETECTED FOR '$baseName'!" -ForegroundColor Red
            Write-Host "     This causes 'Port not recognized' when software targets the wrong copy." -ForegroundColor Yellow
            Write-Host "     * Main Driver   : $baseName (Port: $($live.PortName))" -ForegroundColor White
            foreach ($d in $duplicates) {
                Write-Host "     * Duplicate Copy: $($d.Name) (Port: $($d.PortName))" -ForegroundColor Yellow
            }
        }
        
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
        Write-Host " DIAGNOSTIC & REPAIR COMMANDS (DIRECT FROM TERMINAL):" -ForegroundColor White
        Write-Host " [1]  Option 1: Set this Printer as Default (Fast & Safe)" -ForegroundColor Cyan
        if ($hasDuplicates -or $selPrinter.Name -match '\(Copy') {
            Write-Host " [2]  Option 2: Consolidate Port & Delete Duplicate Copies (Clean Driver Name)" -ForegroundColor Green
        }
        Write-Host " [F]  Open Full Automated Repair Wizard (All Issues)" -ForegroundColor Green
        Write-Host " [P]  Send Native Windows Test Page directly to this Printer (CMD Mode)" -ForegroundColor Cyan
        Write-Host " [C]  Clear / Cancel all pending jobs in this queue" -ForegroundColor Yellow
        Write-Host " [O]  Toggle Printer Online / Offline" -ForegroundColor Yellow
        Write-Host " [R]  Refresh live diagnostics" -ForegroundColor Cyan
        Write-Host " [W]  Launch Web Vector Test Tool (printertestultimate)" -ForegroundColor Magenta
        Write-Host " [0]  Return to Main Menu" -ForegroundColor DarkGray
        Write-Host "================================================================================" -ForegroundColor Cyan

        $diagCmd = Read-Host " Enter command [1, 2, F, P, C, O, R, W, 0]"
        switch ($diagCmd.Trim().ToUpper()) {
            "1" {
                Set-EpsonDefaultPrinter -PrinterName $selPrinter.Name
                Start-Sleep -Seconds 2
            }
            "2" {
                Consolidate-EpsonPrinterCopies -PrimaryName $baseName -TargetPortName $selPrinter.PortName
                Start-Sleep -Seconds 2
            }
            "F" {
                Invoke-PrinterIssueRepairWizard -TargetPrinterName $selPrinter.Name
            }
            "O" {
                Set-PrinterOnline -PrinterName $selPrinter.Name
                Start-Sleep -Seconds 1
            }
            "P" {
                Write-Host "`n[i] Sending native test page to '$($selPrinter.Name)'..." -ForegroundColor Cyan
                try {
                    Start-Process -FilePath "rundll32.exe" -ArgumentList "printui.dll,PrintUIEntry /k /n `"$($selPrinter.Name)`"" -Wait
                    Write-Host "[OK] Native test page command dispatched to printer spooler!" -ForegroundColor Green
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
                            Write-Host "    [OK] Cancelled job #$($j.JobId)" -ForegroundColor Green
                        } catch { }
                    }
                }
                Reset-PrinterSpooler -Silent $true
                Write-Host "[OK] Spooler queue purged and reset!" -ForegroundColor Green
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
        Write-Host "[OK] Diagnostic tool launched in your default web browser!" -ForegroundColor Green
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

    Write-Host "`n[1/5] Scanning for physically connected Epson printer (USB)..." -ForegroundColor Cyan
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

    Write-Host "`n[OK] Identified Series: $($mapping.Series)" -ForegroundColor Green

    Write-Host "`n[2/5] Pre-flight Check: Auto-repairing Print Spooler..." -ForegroundColor Cyan
    Reset-PrinterSpooler -Silent $true
    Write-Host "    [OK] Print queue and spooler port unlocked to prevent Error 20000010." -ForegroundColor Green

    Write-Host "`n[3/5] Checking for Duplicate Driver Copies & Active USB Port..." -ForegroundColor Cyan
    $allEpsPrinters = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Epson*" }
    $copyPrinters = $allEpsPrinters | Where-Object { $_.Name -match '\((Copy|Salinan)\s*\d+\)' }
    if ($copyPrinters) {
        $activeCopy = $copyPrinters[0]
        Write-Host "    [!] Notice: Found duplicate printer driver copy: '$($activeCopy.Name)' on Port '$($activeCopy.PortName)'" -ForegroundColor Yellow
        Write-Host "        Auto-setting '$($activeCopy.Name)' as Default to ensure Adjustment Program communicates properly..." -ForegroundColor Cyan
        Set-EpsonDefaultPrinter -PrinterName $activeCopy.Name | Out-Null
        Write-Host "    [OK] Default printer adjusted to active USB port." -ForegroundColor Green
    } else {
        Write-Host "    [OK] Printer driver configuration is clean (no conflicting duplicate copies)." -ForegroundColor Green
    }

    Write-Host "`n[4/5] Checking Windows Printer Driver..." -ForegroundColor Cyan
    $hasDriver = Test-EpsonDriverInstalled -ModelKeyword $mapping.Driver
    if ($hasDriver) {
        Write-Host "    [OK] Official Epson driver is detected in Windows." -ForegroundColor Green
    } else {
        Write-Host "    [!] Warning: Windows driver for $($mapping.Series) is missing." -ForegroundColor Yellow
        $instChoice = Read-Host "    Press [Enter] to auto-install driver now, or [S] to skip"
        if ($instChoice.Trim().ToUpper() -ne 'S') {
            Install-EpsonDriver -ModelKey $mapping.Driver
        }
    }

    Write-Host "`n[5/5] Launching Adjustment Tool..." -ForegroundColor Cyan
    $toolPath = Join-Path $BinBaseDir $mapping.BinDir
    $fullExe = Join-Path $toolPath $mapping.Exe

    if ($mapping.NeedsPassword) {
        try {
            Set-Clipboard -Value "i-loadzone.com"
            Write-Host "    [KEY] Password 'i-loadzone.com' has been AUTO-COPIED to your clipboard!" -ForegroundColor Yellow
            Write-Host "         (If prompted for password, just press Ctrl + V and hit OK)" -ForegroundColor Yellow
        } catch { }
    }

    Write-Host ""
    Write-Host "+------------------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "|                 FOOLPROOF 4-STEP RESET INSTRUCTIONS                    |" -ForegroundColor Yellow
    Write-Host "+------------------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "| 1. In the program window, click [Particular adjustment mode].          |" -ForegroundColor White
    Write-Host "| 2. Double-click [Waste ink pad counter] in the Maintenance list.       |" -ForegroundColor White
    Write-Host "| 3. Check the box [Main pad counter], then click [Initialize].          |" -ForegroundColor White
    Write-Host "| 4. Turn OFF the printer with power button when prompted, then turn ON! |" -ForegroundColor Green
    Write-Host "+------------------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host ""

    try {
        $proc = Start-Process -FilePath $fullExe -WorkingDirectory $toolPath -PassThru
        Write-Host "[OK] Tool is running! (PID: $($proc.Id))" -ForegroundColor Green
        
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
        Write-Host "[OK] Epson Printer Driver: INSTALLED & DETECTED" -ForegroundColor Green
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
        Write-Host "[OK] Program launched successfully! (PID: $($proc.Id))" -ForegroundColor Green
        
        Write-Host "`n[?] After turning your printer back ON and completing the reset:" -ForegroundColor Yellow
        $prompt = Read-Host "    Do you want to run a Diagnostic Test Print now? (Y/N)"
        if ($prompt.Trim().ToUpper() -eq 'Y') {
            Invoke-PrinterTest
        }
    } catch {
        Write-Host "[x] Failed to launch program: $($_.Exception.Message)" -ForegroundColor Red
    }
}
