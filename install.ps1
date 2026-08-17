# ==============================================================================
# WORKINSTALLER - MAIN CONTROLLER
# Repository: https://github.com/SimoGHcoder/WorkInstaller
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Elevazione Amministratore
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Riavvio con privilegi di Amministratore..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Configurazione GitHub
$global:owner   = "SimoGHcoder"
$global:repo    = "WorkInstaller"

$rawUrls = @(
    "https://raw.githubusercontent.com/$global:owner/$global:repo/main",
    "https://raw.githubusercontent.com/$global:owner/$global:repo/master"
)
$global:apiBase = "https://api.github.com/repos/$global:owner/$global:repo/contents"

# Funzioni Helper Condivise
function Get-SilentArgs ([string]$fileName) {
    if ($fileName.EndsWith(".msi")) { return "/qn /norestart" } else { return "/S" }
}

function Install-WingetApp ([string]$id, [string]$name) {
    Write-Host "--> [Winget] Installazione di $name ($id)..." -ForegroundColor Yellow
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements
}

function Install-CustomApp ([string]$downloadUrl, [string]$fileName) {
    $tempFolder = "$env:TEMP\WorkInstaller"
    if (-not (Test-Path $tempFolder)) { New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null }
    $outPath = Join-Path $tempFolder $fileName

    Write-Host "--> [Custom] Download di $fileName..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outPath -UseBasicParsing
    
    Write-Host "--> [Custom] Esecuzione interattiva $fileName..." -ForegroundColor Yellow
    Start-Process -FilePath $outPath -Wait
    
    if (Test-Path $outPath) { Remove-Item $outPath -Force -ErrorAction SilentlyContinue }
    Write-Host "--> Completato!" -ForegroundColor Green
}

function Execute-BatchTask ([string]$downloadUrl, [string]$fileName) {
    $tempFolder = "$env:TEMP\WorkInstaller"
    if (-not (Test-Path $tempFolder)) { New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null }
    $outPath = Join-Path $tempFolder $fileName

    Write-Host "--> [Task] Download dello script $fileName..." -ForegroundColor Cyan
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $outPath -UseBasicParsing -ErrorAction Stop
        
        # Sblocca il file scaricato per evitare blocchi da ExecutionPolicy/SmartScreen
        Unblock-File -Path $outPath -ErrorAction SilentlyContinue

        Write-Host "--> [Task] Esecuzione di $fileName in corso..." -ForegroundColor Yellow
        
        if ($fileName.EndsWith(".ps1")) {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$outPath"
        } else {
            cmd.exe /c "$outPath"
        }
        
        Write-Host "--> [Task] Esecuzione completata!" -ForegroundColor Green
    }
    catch {
        Write-Host " [!] Errore durante l'esecuzione dello script: $_" -ForegroundColor Red
    }
    finally {
        if (Test-Path $outPath) { Remove-Item $outPath -Force -ErrorAction SilentlyContinue }
    }
}

# Download ed Esecuzione Moduli
function Load-SingleModule ([string]$moduleName) {
    $loaded = $false
    foreach ($baseUrl in $rawUrls) {
        $fullUrl = "$baseUrl/$moduleName"
        try {
            $code = Invoke-RestMethod -Uri $fullUrl -UseBasicParsing -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($code)) {
                Invoke-Expression $code
                Write-Host " [OK] Modulo $moduleName caricato" -ForegroundColor Green
                $global:workingRawBase = $baseUrl
                $loaded = $true
                break
            }
        } catch {
            # Prova con il fallback
        }
    }
    if (-not $loaded) {
        Write-Host " [ERRORE] Impossibile caricare $moduleName" -ForegroundColor Red
    }
}

function Load-AllModules {
    Write-Host "Sincronizzazione moduli da GitHub..." -ForegroundColor Cyan
    Load-SingleModule "module-winget.ps1"
    Load-SingleModule "module-custom.ps1"
    Load-SingleModule "module-tasks.ps1"
    Load-SingleModule "module-utility.ps1"
    
    if ($global:workingRawBase) {
        $global:rawBase = $global:workingRawBase
    } else {
        $global:rawBase = $rawUrls[0]
    }
}

function Reload-All {
    Load-AllModules
    
    if (Get-Command Get-ModuleWingetList -ErrorAction SilentlyContinue) {
        $global:wingetList = Get-ModuleWingetList
    } else { $global:wingetList = @() }

    if (Get-Command Get-ModuleCustomList -ErrorAction SilentlyContinue) {
        $global:customList = Get-ModuleCustomList
    } else { $global:customList = @() }

    if (Get-Command Get-ModuleTasksList -ErrorAction SilentlyContinue) {
        $global:taskList = Get-ModuleTasksList
    } else { $global:taskList = @() }

    Start-Sleep -Seconds 1
}

# Primo caricamento
Reload-All

# Menu Principale
do {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "     WORKINSTALLER - DEPLOYMENT UTILS    " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $index = 1

    if (Get-Command Show-ModuleWingetMenu -ErrorAction SilentlyContinue) {
        Show-ModuleWingetMenu -startIndex ([ref]$index)
    } else {
        Write-Host " --- 1. SOFTWARE STANDARD (WINGET) ---" -ForegroundColor DarkGray
        Write-Host " (Errore: Modulo module-winget.ps1 non disponibile)" -ForegroundColor Red
    }

    if (Get-Command Show-ModuleCustomMenu -ErrorAction SilentlyContinue) {
        Show-ModuleCustomMenu -startIndex ([ref]$index)
    } else {
        Write-Host "`n --- 2. INSTALLER CUSTOM (INSTALLER/) ---" -ForegroundColor DarkGray
        Write-Host " (Errore: Modulo module-custom.ps1 non disponibile)" -ForegroundColor Red
    }

    if (Get-Command Show-ModuleTasksMenu -ErrorAction SilentlyContinue) {
        Show-ModuleTasksMenu -startIndex ([ref]$index)
    } else {
        Write-Host "`n --- 3. OPERAZIONI BATCH (TASKS/) ---" -ForegroundColor DarkGray
        Write-Host " (Errore: Modulo module-tasks.ps1 non disponibile)" -ForegroundColor Red
    }

    if (Get-Command Show-ModuleUtilityMenu -ErrorAction SilentlyContinue) {
        Show-ModuleUtilityMenu
    } else {
        Write-Host "`n --- 4. UTILITY ---" -ForegroundColor DarkGray
        Write-Host "[R] Ricarica moduli"
        Write-Host "[Q] Esci"
        Write-Host "========================================="
    }

    $selection = Read-Host "Seleziona un'opzione (es. 1, 3, 5 per Winget)"

    # Se l'input contiene numeri (singoli o multipli separati da spazio/virgola)
    if ($selection -match '\d') {
        # Estrae il primo numero valido per determinare la sezione target
        $firstNumber = ($selection -split '[\s,]' | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1) -as [int]
        
        if ($firstNumber -ge 1 -and $firstNumber -lt $index) {
            $wCount = $global:wingetList.Count
            $cCount = $global:customList.Count

            # Selezione appartenente alla sezione Winget
            if ($firstNumber -le $wCount) {
                Invoke-ModuleWingetAction -inputSelection $selection
            }
            # Selezione appartenente alla sezione Custom
            elseif ($firstNumber -le ($wCount + $cCount)) {
                Invoke-ModuleCustomAction -index ($firstNumber - $wCount - 1)
            }
            # Selezione appartenente alla sezione Tasks
            else {
                Invoke-ModuleTasksAction -index ($firstNumber - $wCount - $cCount - 1)
            }
            Start-Sleep -Seconds 2
        }
    }
    else {
        # Gestione opzioni testuali (W, M, R, Q...)
        if (Get-Command Invoke-ModuleUtilityAction -ErrorAction SilentlyContinue) {
            Invoke-ModuleUtilityAction -code $selection
        } elseif ($selection -eq 'R' -or $selection -eq 'r') {
            Reload-All
        }
    }

} until ($selection -eq 'Q' -or $selection -eq 'q')
