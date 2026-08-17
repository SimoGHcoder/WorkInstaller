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

# Modulo 1: Lettura App Winget da winget-apps.txt
function Get-WingetApps {
    try {
        $content = Invoke-RestMethod -Uri "$rawBase/winget-apps.txt" -ErrorAction Stop
        $lines = $content -split "`r?`n" | Where-Object { $_ -match '\|' -and -not $_.StartsWith("#") }
        $apps = @()
        foreach ($line in $lines) {
            $parts = $line.Split('|')
            $apps += [PSCustomObject]@{ Name = $parts[0].Trim(); Id = $parts[1].Trim() }
        }
        return $apps
    } catch { return @() }
}

# Modulo 2: Scansione Eseguibili Custom (.exe / .msi)
function Get-CustomInstallers {
    try {
        $res = Invoke-RestMethod -Uri "$apiBase/installer" -Method Get -Headers @{ "User-Agent" = "PowerShell" } -ErrorAction Stop
        return $res | Where-Object { $_.type -eq "file" -and ($_.name -like "*.exe" -or $_.name -like "*.msi") }
    } catch { return @() }
}

# Modulo 3: Scansione Script di Operazioni Batch (.ps1 / .bat)
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
            Write-Host "[$index] $($file.name)"
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
    Write-Host " --- AZIONI DI SISTEMA ---" -ForegroundColor DarkGray
    Write-Host "[A] Esegui INSTALLAZIONE COMPLETA (Tutti i software)"
    Write-Host "[R] Ricarica moduli da GitHub"
    Write-Host "[Q] Esci"
    Write-Host "========================================="

    $selection = Read-Host "Seleziona un'opzione"

    if ($selection -match '^[0-9]+$') {
        $val = [int]$selection
        
        # Gestione selezione dinamica
        if ($val -ge 1 -and $val -lt $index) {
            $wCount = $wingetList.Count
            $cCount = $customList.Count

            if ($val -le $wCount) {
                # Cliccata App Winget
                $app = $wingetList[$val - 1]
                Install-WingetApp -id $app.Id -name $app.Name
                Start-Sleep -Seconds 2
            }
            elseif ($val -le ($wCount + $cCount)) {
                # Cliccato Installer Custom
                $file = $customList[$val - $wCount - 1]
                Install-CustomApp -downloadUrl "$rawBase/installer/$($file.name)" -fileName $file.name
                Start-Sleep -Seconds 2
            }
            else {
                # Cliccata Operazione Batch / Task
                $task = $taskList[$val - $wCount - $cCount - 1]
                Execute-BatchTask -downloadUrl "$rawBase/tasks/$($task.name)" -fileName $task.name
                Start-Sleep -Seconds 2
            }
        }
    }
    elseif ($selection -eq 'A' -or $selection -eq 'a') {
        Write-Host "Avvio installazione di massa..." -ForegroundColor Green
        foreach ($app in $wingetList) { Install-WingetApp -id $app.Id -name $app.Name }
        foreach ($file in $customList) { Install-CustomApp -downloadUrl "$rawBase/installer/$($file.name)" -fileName $file.name }
        Write-Host "Installazioni completate!" -ForegroundColor Green
        Start-Sleep -Seconds 3
    }
    elseif ($selection -eq 'R' -or $selection -eq 'r') {
        Reload-AllModules
    }

} until ($selection -eq 'Q' -or $selection -eq 'q')
