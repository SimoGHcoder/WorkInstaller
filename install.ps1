# ==============================================================================
# SCRIPT INSTALLAZIONE SOFTWARE SCUOLA (100% DINAMICO)
# Repository: https://github.com/SimoGHcoder/WorkInstaller
# ==============================================================================

# 1. Forza l'uso di TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Verifica privilegi di Amministratore
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Riavvio dello script con privilegi di Amministratore..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 3. Configurazione Repository e API GitHub
$owner      = "SimoGHcoder"
$repo       = "WorkInstaller"
$apiUrl     = "https://api.github.com/repos/$owner/$repo/contents/installer"
$rawBase    = "https://raw.githubusercontent.com/$owner/$repo/refs/heads/main"
$wingetTxt  = "$rawBase/winget-apps.txt"

# Funzione per leggere l'elenco delle app Winget dal file TXT
function Get-WingetApps {
    try {
        $content = Invoke-RestMethod -Uri $wingetTxt -ErrorAction Stop
        $lines = $content -split "`r?`n" | Where-Object { $_ -match '\|' -and -not $_.StartsWith("#") }
        $apps = @()
        foreach ($line in $lines) {
            $parts = $line.Split('|')
            $apps += [PSCustomObject]@{
                Name = $parts[0].Trim()
                Id   = $parts[1].Trim()
            }
        }
        return $apps
    } catch {
        return @()
    }
}

# Funzione per recuperare i file custom (.exe e .msi) dalla cartella 'installer'
function Get-CustomFiles {
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ "User-Agent" = "PowerShell" } -ErrorAction Stop
        $files = $response | Where-Object { $_.type -eq "file" -and ($_.name -like "*.exe" -or $_.name -like "*.msi") }
        return $files
    } catch {
        return @()
    }
}

function Get-SilentArgs ([string]$fileName) {
    if ($fileName.EndsWith(".msi")) { return "/qn /norestart" } else { return "/S" }
}

function Install-WingetApp ([string]$id, [string]$name) {
    Write-Host "--> Installazione di $name ($id) tramite Winget..." -ForegroundColor Yellow
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements
}

function Install-CustomApp ([string]$downloadUrl, [string]$fileName, [string]$arguments) {
    $outPath = "$env:TEMP\$fileName"
    Write-Host "--> Download di $fileName in corso..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outPath -UseBasicParsing
    
    Write-Host "--> Esecuzione installazione per $fileName..." -ForegroundColor Yellow
    Start-Process -FilePath $outPath -ArgumentList $arguments -Wait -PassThru
    
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    Write-Host "--> Completato!" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

# Caricamento iniziale dei dati
Write-Host "Caricamento configurazioni da GitHub in corso..." -ForegroundColor Cyan
$wingetApps = Get-WingetApps
$customFiles = Get-CustomFiles

do {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "     WORKINSTALLER - DEPLOYMENT UTILS    " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # 1. Menu Winget Dinamico
    Write-Host " --- SOFTWARE STANDARD (WINGET) ---" -ForegroundColor DarkGray
    if ($wingetApps.Count -eq 0) {
        Write-Host " (Nessuna app configurata in winget-apps.txt)" -ForegroundColor Gray
    } else {
        for ($i = 0; $i -lt $wingetApps.Count; $i++) {
            $num = $i + 1
            Write-Host "[$num] $($wingetApps[$i].Name)"
        }
    }
    
    # 2. Menu Custom Dinamico
    Write-Host ""
    Write-Host " --- SOFTWARE PERSONALIZZATI (INSTALLER) ---" -ForegroundColor DarkGray
    $offset = $wingetApps.Count
    if ($customFiles.Count -eq 0) {
        Write-Host " (Nessun file .exe/.msi trovato nella cartella 'installer')" -ForegroundColor Gray
    } else {
        for ($j = 0; $j -lt $customFiles.Count; $j++) {
            $num = $j + $offset + 1
            Write-Host "[$num] $($customFiles[$j].name)"
        }
    }
    
    Write-Host ""
    Write-Host " --- OPERAZIONI BATCH ---" -ForegroundColor DarkGray
    Write-Host "[A] Installa TUTTI i programmi (Winget + Custom)"
    Write-Host "[R] Ricarica configurazioni da GitHub"
    Write-Host "[Q] Esci"
    Write-Host "========================================="
    
    $selection = Read-Host "Seleziona un'opzione"
    
    if ($selection -match '^[0-9]+$') {
        $val = [int]$selection
        
        # Scelta app Winget
        if ($val -ge 1 -and $val -le $wingetApps.Count) {
            $app = $wingetApps[$val - 1]
            Install-WingetApp -id $app.Id -name $app.Name
            Start-Sleep -Seconds 2
        }
        # Scelta file Custom
        elseif ($val -gt $wingetApps.Count -and $val -le ($wingetApps.Count + $customFiles.Count)) {
            $index = $val - $wingetApps.Count - 1
            $fileObj = $customFiles[$index]
            $fileUrl = "$rawBase/installer/$($fileObj.name)"
            $args = Get-SilentArgs $fileObj.name
            Install-CustomApp -downloadUrl $fileUrl -fileName $fileObj.name -arguments $args
        }
    } 
    elseif ($selection -eq 'A' -or $selection -eq 'a') {
        Write-Host "Avvio installazione completa di massa..." -ForegroundColor Green
        
        # Installa tutte le app Winget
        foreach ($app in $wingetApps) {
            Install-WingetApp -id $app.Id -name $app.Name
        }
        
        # Installa tutti i file Custom
        foreach ($fileObj in $customFiles) {
            $fileUrl = "$rawBase/installer/$($fileObj.name)"
            $args = Get-SilentArgs $fileObj.name
            Install-CustomApp -downloadUrl $fileUrl -fileName $fileObj.name -arguments $args
        }
        
        Write-Host "Tutte le installazioni sono state completate!" -ForegroundColor Green
        Start-Sleep -Seconds 3
    } 
    elseif ($selection -eq 'R' -or $selection -eq 'r') {
        Write-Host "Aggiornamento dati da GitHub..." -ForegroundColor Yellow
        $wingetApps = Get-WingetApps
        $customFiles = Get-CustomFiles
    }

} until ($selection -eq 'Q' -or $selection -eq 'q')
