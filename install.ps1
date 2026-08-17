# ==============================================================================
# WORKINSTALLER - MAIN CONTROLLER
# Repository: https://github.com/SimoGHcoder/WorkInstaller
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Riavvio con privilegi di Amministratore..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Configurazione globale
$global:owner   = "SimoGHcoder"
$global:repo    = "WorkInstaller"
$global:rawBase = "https://raw.githubusercontent.com/$global:owner/$global:repo/refs/heads/main"
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

# Inclusione dei 4 script di modulo
function Load-Modules {
    Write-Host "Caricamento moduli da GitHub..." -ForegroundColor Cyan
    Invoke-Expression (Invoke-RestMethod -Uri "$global:rawBase/module-winget.ps1" -UseBasicParsing)
    Invoke-Expression (Invoke-RestMethod -Uri "$global:rawBase/module-custom.ps1" -UseBasicParsing)
    Invoke-Expression (Invoke-RestMethod -Uri "$global:rawBase/module-tasks.ps1" -UseBasicParsing)
    Invoke-Expression (Invoke-RestMethod -Uri "$global:rawBase/module-utility.ps1" -UseBasicParsing)
}

function Reload-All {
    Load-Modules
    $global:wingetList = Get-ModuleWingetList
    $global:customList = Get-ModuleCustomList
    $global:taskList   = Get-ModuleTasksList
}

Reload-All

do {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "     WORKINSTALLER - DEPLOYMENT UTILS    " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $index = 1

    # 1. Software Winget
    Show-ModuleWingetMenu -startIndex ([ref]$index)

    # 2. Installer Custom
    Show-ModuleCustomMenu -startIndex ([ref]$index)

    # 3. Operazioni Batch
    Show-ModuleTasksMenu -startIndex ([ref]$index)

    # 4. Operazioni Massive e Utility
    Show-ModuleUtilityMenu

    $selection = Read-Host "Seleziona un'opzione"

    if ($selection -match '^[0-9]+$') {
        $val = [int]$selection
        if ($val -ge 1 -and $val -lt $index) {
            $wCount = $global:wingetList.Count
            $cCount = $global:customList.Count

            if ($val -le $wCount) {
                Invoke-ModuleWingetAction -index ($val - 1)
            }
            elseif ($val -le ($wCount + $cCount)) {
                Invoke-ModuleCustomAction -index ($val - $wCount - 1)
            }
            else {
                Invoke-ModuleTasksAction -index ($val - $wCount - $cCount - 1)
            }
            Start-Sleep -Seconds 2
        }
    }
    else {
        Invoke-ModuleUtilityAction -code $selection
    }

} until ($selection -eq 'Q' -or $selection -eq 'q')
