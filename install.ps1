# ==============================================================================
# WORKINSTALLER - RUNNER PRINCIPALE MODULARE
# Repository: https://github.com/SimoGHcoder/WorkInstaller
# ==============================================================================

# 1. Forza protocollo di sicurezza TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Controllo e richiesta elevazione ad Amministratore
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Riavvio in corso con privilegi di Amministratore..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 3. Parametri Repository GitHub
$owner    = "SimoGHcoder"
$repo     = "WorkInstaller"
$rawBase  = "https://raw.githubusercontent.com/$owner/$repo/refs/heads/main"
$apiBase  = "https://api.github.com/repos/$owner/$repo/contents"

# --- FUNZIONI DI RECUPERO MODULI ---

function Get-WingetApps {
    try {
        $content = Invoke-RestMethod -Uri "$rawBase/winget-apps.txt" -ErrorAction Stop
        $lines = $content -split "`r?`n" | Where-Object { $_ -match '\|' -and -not $_.StartsWith("#") }
        $apps = @()
        foreach ($line in $lines) {
            $parts = $line.Split('|')
            $apps += [PSCustomObject]@{ Name = $parts[0].Trim(); Id = $parts[1].Trim(); Type = "Winget" }
        }
        return $apps
    } catch { return @() }
}

function Get-CustomInstallers {
    try {
        $res = Invoke-RestMethod -Uri "$apiBase/installer" -Method Get -Headers @{ "User-Agent" = "PowerShell" } -ErrorAction Stop
        $files = $res | Where-Object { $_.type -eq "file" -and ($_.name -like "*.exe" -or $_.name -like "*.msi") }
        $installers = @()
        foreach ($f in $files) {
            $installers += [PSCustomObject]@{ Name = $f.name; DownloadUrl = "$rawBase/installer/$($f.name)"; Type = "Custom" }
        }
        return $installers
    } catch { return @() }
}

function Get-BatchTasks {
    try {
        $res = Invoke-RestMethod -Uri "$apiBase/tasks" -Method Get -Headers @{ "User-Agent" = "PowerShell" } -ErrorAction Stop
        return $res | Where-Object { $_.type -eq "file" -and ($_.name -like "*.ps1" -or $_.name -like "*.bat") }
    } catch { return @() }
}

# --- FUNZIONI DI ESECUZIONE ---

function Get-SilentArgs ([string]$fileName) {
    if ($fileName.EndsWith(".msi")) { return "/qn /norestart" } else { return "/S" }
}

function Install-WingetApp ([string]$id, [string]$name) {
    Write-Host "--> [Winget] Installazione di $name ($id)..." -ForegroundColor Yellow
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements
}

function Install-CustomApp ([string]$downloadUrl, [string]$fileName) {
    $outPath = "$env:TEMP\$fileName"
    $args = Get-SilentArgs $fileName
    Write-Host "--> [Custom] Download di $fileName..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outPath -UseBasicParsing
    
    Write-Host "--> [Custom] Esecuzione $fileName..." -ForegroundColor Yellow
    Start-Process -FilePath $outPath -ArgumentList $args -Wait -PassThru
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    Write-Host "--> Completato!" -ForegroundColor Green
}

function Execute-BatchTask ([string]$downloadUrl, [string]$fileName) {
    $outPath = "$env:TEMP\$fileName"
    Write-Host "--> [Task] Download dello script $fileName..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outPath -UseBasicParsing
    
    Write-Host "--> [Task] Esecuzione in corso..." -ForegroundColor Yellow
    if ($fileName.EndsWith(".ps1")) {
        powershell -ExecutionPolicy Bypass -File $outPath
    } else {
        cmd /c $outPath
    }
    
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    Write-Host "--> Task completato!" -ForegroundColor Green
}

# --- CARICAMENTO INIZIALE E CICLO MENU ---

function Reload-AllModules {
    Write-Host "Sincronizzazione moduli da GitHub..." -ForegroundColor Cyan
    $global:wingetList  = Get-WingetApps
    $global:customList  = Get-CustomInstallers
    $global:taskList    = Get-BatchTasks
}

# Sub-Menu per Selezione Personalizzata di Software
function Show-CustomMultiSelect {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   INSTALLAZIONE MASSIVA PERSONALIZZATA  " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $allSoftware = @()
    $idx = 1

    Write-Host "--- SOFTWARE DISPONIBILI ---" -ForegroundColor DarkGray
    foreach ($app in $wingetList) {
        Write-Host "[$idx] [Winget] $($app.Name)"
        $allSoftware += [PSCustomObject]@{ Number = $idx; Object = $app; Type = "Winget" }
        $idx++
    }
    foreach ($file in $customList) {
        Write-Host "[$idx] [Custom] $($file.Name)"
        $allSoftware += [PSCustomObject]@{ Number = $idx; Object = $file; Type = "Custom" }
        $idx++
    }

    if ($allSoftware.Count -eq 0) {
        Write-Host "Nessun software disponibile per l'installazione." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    Write-Host ""
    Write-Host "Inserisci i numeri dei software da installare separati da virgola (es: 1,3,5)" -ForegroundColor Yellow
    $inputRaw = Read-Host "Selezione (lascia vuoto per annullare)"

    if ([string]::IsNullOrWhiteSpace($inputRaw)) { return }

    $selectedIndices = $inputRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' } | ForEach-Object { [int]$_ }

    Write-Host ""
    Write-Host "Avvio installazione dei software selezionati..." -ForegroundColor Green

    foreach ($num in $selectedIndices) {
        $item = $allSoftware | Where-Object { $_.Number -eq $num }
        if ($item) {
            if ($item.Type -eq "Winget") {
                Install-WingetApp -id $item.Object.Id -name $item.Object.Name
            }
            elseif ($item.Type -eq "Custom") {
                Install-CustomApp -downloadUrl $item.Object.DownloadUrl -fileName $item.Object.Name
            }
        } else {
            Write-Host "Numero $num non valido, ignorato." -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Tutte le installazioni selezionate sono state completate!" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

Reload-AllModules

do {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "     WORKINSTALLER - DEPLOYMENT UTILS    " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $index = 1

    # 1. SEZIONE WINGET
    Write-Host " --- 1. SOFTWARE STANDARD (WINGET) ---" -ForegroundColor DarkGray
    if ($wingetList.Count -eq 0) {
        Write-Host " (Nessuna app definita in winget-apps.txt)" -ForegroundColor Gray
    } else {
        foreach ($app in $wingetList) {
            Write-Host "[$index] $($app.Name)"
            $index++
        }
    }

    # 2. SEZIONE INSTALLER CUSTOM
    Write-Host ""
    Write-Host " --- 2. INSTALLER CUSTOM (INSTALLER/) ---" -ForegroundColor DarkGray
    if ($customList.Count -eq 0) {
        Write-Host " (Nessun file .exe/.msi nella cartella 'installer')" -ForegroundColor Gray
    } else {
        foreach ($file in $customList) {
            Write-Host "[$index] $($file.Name)"
            $index++
        }
    }

    # 3. SEZIONE OPERAZIONI BATCH / TASK
    Write-Host ""
    Write-Host " --- 3. OPERAZIONI BATCH (TASKS/) ---" -ForegroundColor DarkGray
    if ($taskList.Count -eq 0) {
        Write-Host " (Nessuno script trovato nella cartella 'tasks')" -ForegroundColor Gray
    } else {
        foreach ($task in $taskList) {
            Write-Host "[$index] $($task.name)"
            $index++
        }
    }

    Write-Host ""
    Write-Host " --- OPERAZIONI MASSIVE E UTILITY ---" -ForegroundColor DarkGray
    Write-Host "[W] Installa TUTTE le app Winget"
    Write-Host "[M] SELEZIONE MULTIPLA PERSONALIZZATA (Scegli cosa installare)"
    Write-Host "[R] Ricarica moduli da GitHub"
    Write-Host "[Q] Esci"
    Write-Host "========================================="

    $selection = Read-Host "Seleziona un'opzione"

    if ($selection -match '^[0-9]+$') {
        $val = [int]$selection
        
        if ($val -ge 1 -and $val -lt $index) {
            $wCount = $wingetList.Count
            $cCount = $customList.Count

            if ($val -le $wCount) {
                $app = $wingetList[$val - 1]
                Install-WingetApp -id $app.Id -name $app.Name
                Start-Sleep -Seconds 2
            }
            elseif ($val -le ($wCount + $cCount)) {
                $file = $customList[$val - $wCount - 1]
                Install-CustomApp -downloadUrl $file.DownloadUrl -fileName $file.Name
                Start-Sleep -Seconds 2
            }
            else {
                $task = $taskList[$val - $wCount - $cCount - 1]
                Execute-BatchTask -downloadUrl "$rawBase/tasks/$($task.name)" -fileName $task.name
                Start-Sleep -Seconds 2
            }
        }
    }
    elseif ($selection -eq 'W' -or $selection -eq 'w') {
        Write-Host "Avvio installazione di massa (tutti i software Winget)..." -ForegroundColor Green
        foreach ($app in $wingetList) { Install-WingetApp -id $app.Id -name $app.Name }
        Write-Host "Installazioni Winget completate!" -ForegroundColor Green
        Start-Sleep -Seconds 3
    }
    elseif ($selection -eq 'M' -or $selection -eq 'm') {
        Show-CustomMultiSelect
    }
    elseif ($selection -eq 'R' -or $selection -eq 'r') {
        Reload-AllModules
    }

} until ($selection -eq 'Q' -or $selection -eq 'q')
