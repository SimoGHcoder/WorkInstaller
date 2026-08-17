# ==============================================================================
# WORKINSTALLER - MAIN CONTROLLER
# Repository: https://github.com/SimoGHcoder/WorkInstaller
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ------------------------------------------------------------------------------
# 1. ELEVAZIONE PRIVILEGI AMMINISTRATORE
# ------------------------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Riavvio con privilegi di Amministratore..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Imposta la cartella di lavoro temporanea
Set-Location -Path $env:TEMP

# ------------------------------------------------------------------------------
# 2. CONFIGURAZIONE GITHUB & VARIABILI GLOBALI
# ------------------------------------------------------------------------------
$global:owner   = "SimoGHcoder"
$global:repo    = "WorkInstaller"

# L'URL 'raw.githubusercontent.com' è l'unico che restituisce il codice puro anziché la pagina HTML di GitHub
$global:rawBase = "https://raw.githubusercontent.com/$global:owner/$global:repo/main"
$global:apiBase = "https://api.github.com/repos/$global:owner/$global:repo/contents"

$global:webHeaders = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell/WorkInstaller"
}

# ------------------------------------------------------------------------------
# 3. FUNZIONI HELPER CONDIVISE
# ------------------------------------------------------------------------------
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
    Invoke-WebRequest -Uri $downloadUrl -Headers $global:webHeaders -OutFile $outPath -UseBasicParsing
    
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
        Invoke-WebRequest -Uri $downloadUrl -Headers $global:webHeaders -OutFile $outPath -UseBasicParsing -ErrorAction Stop
        Unblock-File -Path $outPath -ErrorAction SilentlyContinue

        Write-Host "--> [Task] Esecuzione di $fileName in corso..." -ForegroundColor Yellow
        
        if ($fileName.EndsWith(".ps1")) {
            Start-Process powershell.exe `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$outPath`"" `
                -WorkingDirectory $tempFolder `
                -NoNewWindow:$false `
                -Wait
        } else {
            Start-Process "cmd.exe" `
                -ArgumentList "/c `"$outPath`"" `
                -WorkingDirectory $tempFolder `
                -NoNewWindow:$false `
                -Wait
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

# ------------------------------------------------------------------------------
# 4. CARICAMENTO E GESTIONE MODULI DALLA RADICE
# ------------------------------------------------------------------------------
function Load-SingleModule ([string]$moduleName) {
    $fullUrl = "$global:rawBase/$moduleName"
    try {
        $code = Invoke-RestMethod -Uri $fullUrl -Headers $global:webHeaders -UseBasicParsing -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($code)) {
            # Verifica che il codice scaricato non contenga HTML
            if ($code -match "^\s*<!DOCTYPE html>") {
                Write-Host " [ERRORE] $moduleName ha restituito una pagina HTML invece dello script PowerShell." -ForegroundColor Red
                return
            }
            Invoke-Expression $code
            Write-Host " [OK] Modulo $moduleName caricato" -ForegroundColor Green
        }
    } catch {
        Write-Host " [ERRORE DI SINTASSI O DOWNLOAD] Impossibile eseguire $moduleName :" -ForegroundColor Red
        Write-Host " $_" -ForegroundColor Red
    }
}

function Load-AllModules {
    Write-Host "Sincronizzazione moduli da GitHub..." -ForegroundColor Cyan
    Load-SingleModule "module-winget.ps1"
    Load-SingleModule "module-custom.ps1"
    Load-SingleModule "module-tasks.ps1"
    Load-SingleModule "module-utility.ps1"
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

# Primo caricamento all'avvio
Reload-All

# ------------------------------------------------------------------------------
# 5. CICLO PRINCIPALE DEL MENU
# ------------------------------------------------------------------------------
do {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "     WORKINSTALLER - DEPLOYMENT UTILS    " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $index = 1

    if (Get-Command Show-ModuleWingetMenu -ErrorAction SilentlyContinue) {
        Show-ModuleWingetMenu ([ref]$index)
    } else {
        Write-Host " --- 1. SOFTWARE STANDARD (WINGET) ---" -ForegroundColor DarkGray
        Write-Host " (Errore: Modulo module-winget.ps1 non disponibile)" -ForegroundColor Red
    }

    if (Get-Command Show-ModuleCustomMenu -ErrorAction SilentlyContinue) {
        Show-ModuleCustomMenu ([ref]$index)
    } else {
        Write-Host "`n --- 2. INSTALLER CUSTOM (INSTALLER/) ---" -ForegroundColor DarkGray
        Write-Host " (Errore: Modulo module-custom.ps1 non disponibile)" -ForegroundColor Red
    }

    if (Get-Command Show-ModuleTasksMenu -ErrorAction SilentlyContinue) {
        Show-ModuleTasksMenu ([ref]$index)
    } else {
        Write-Host "`n --- 3. OPERAZIONI BATCH (TASKS/) ---" -ForegroundColor DarkGray
        Write-Host " (Errore: Modulo module-tasks.ps1 non disponibile)" -ForegroundColor Red
    }

    if (Get-Command Show-ModuleUtilityMenu -ErrorAction SilentlyContinue) {
        Show-ModuleUtilityMenu
    } else {
        Write-Host "`n --- 4. UTILITY ---" -ForegroundColor DarkGray
        Write-Host " [R] Ricarica moduli"
        Write-Host " [Q] Esci"
        Write-Host "========================================="
    }

    $selection = Read-Host "`nSeleziona un'opzione (es. 1, 3, 5 per Winget)"

    if ($selection -match '\d') {
        $firstNumber = ($selection -split '[\s,]' | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1) -as [int]
        
        if ($firstNumber -ge 1 -and $firstNumber -lt $index) {
            $wCount = if ($global:wingetList) { $global:wingetList.Count } else { 0 }
            $cCount = if ($global:customList) { $global:customList.Count } else { 0 }

            if ($firstNumber -le $wCount) {
                Invoke-ModuleWingetAction -inputSelection $selection
            }
            elseif ($firstNumber -le ($wCount + $cCount)) {
                Invoke-ModuleCustomAction -index ($firstNumber - $wCount - 1)
            }
            else {
                Invoke-ModuleTasksAction -index ($firstNumber - $wCount - $cCount - 1)
            }
            Start-Sleep -Seconds 2
        }
    }
    else {
        if ($selection -eq 'R' -or $selection -eq 'r') {
            Reload-All
        } elseif (Get-Command Invoke-ModuleUtilityAction -ErrorAction SilentlyContinue) {
            Invoke-ModuleUtilityAction -code $selection
        }
    }

} until ($selection -eq 'Q' -or $selection -eq 'q')
