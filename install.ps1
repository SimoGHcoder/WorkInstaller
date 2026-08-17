# ==============================================================================
# SCRIPT INSTALLAZIONE SOFTWARE SCUOLA (DINAMICO)
# Repository: https://github.com/SimoGHcoder/WorkInstaller
# ==============================================================================

# 1. Forza l'uso di TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Verifica e richiesta privilegi di Amministratore
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Riavvio dello script con privilegi di Amministratore..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 3. Configurazione Repository e API GitHub
$owner   = "SimoGHcoder"
$repo    = "WorkInstaller"
$apiUrl  = "https://api.github.com/repos/$owner/$repo/contents/installer"
$rawBase = "https://raw.githubusercontent.com/$owner/$repo/refs/heads/main/installer"

# Funzione per recuperare la lista dei file eseguibili dalla cartella 'installer'
function Get-CustomFiles {
    try {
        # Chiama l'API di GitHub
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ "User-Agent" = "PowerShell" } -ErrorAction Stop
        
        # Filtra SOLO i file con estensione .exe e .msi (ignorando .gitkeep, .md, ecc.)
        $files = $response | Where-Object { $_.type -eq "file" -and ($_.name -like "*.exe" -or $_.name -like "*.msi") }
        return $files
    } catch {
        return @()
    }
}

# Determina i parametri di installazione silenziosa di default
function Get-SilentArgs ([string]$fileName) {
    if ($fileName.EndsWith(".msi")) {
        return "/qn /norestart"
    } else {
        return "/S"
    }
}

function Install-WingetApp ([string]$id) {
    Write-Host "--> Installazione di $id tramite Winget..." -ForegroundColor Yellow
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements
}

function Install-CustomApp ([string]$downloadUrl, [string]$fileName, [string]$arguments) {
    $outPath = "$env:TEMP\$fileName"
    
    Write-Host "--> Download di $fileName in corso..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outPath -UseBasicParsing
    
    Write-Host "--> Esecuzione installazione per $fileName ($arguments)..." -ForegroundColor Yellow
    Start-Process -FilePath $outPath -ArgumentList $arguments -Wait -PassThru
    
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    Write-Host "--> Completato!" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# Lettura iniziale della cartella 'installer' da GitHub
Write-Host "Scansione cartella 'installer' su GitHub..." -ForegroundColor Cyan
$customFiles = Get-CustomFiles

do {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "     WORKINSTALLER - DEPLOYMENT UTILS    " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host " --- SOFTWARE STANDARD (WINGET) ---" -ForegroundColor DarkGray
    Write-Host "[1] Google Chrome"
    Write-Host "[2] Mozilla Firefox"
    Write-Host "[3] LibreOffice"
    Write-Host "[4] 7-Zip"
    Write-Host ""
    
    # Generazione dinamica del menu per i file Custom
    Write-Host " --- SOFTWARE PERSONALIZZATI (AUTO-DETECT) ---" -ForegroundColor DarkGray
    if ($customFiles.Count -eq 0) {
        Write-Host " (Nessun file .exe/.msi trovato nella cartella 'installer')" -ForegroundColor Gray
    } else {
        for ($i = 0; $i -lt $customFiles.Count; $i++) {
            $num = $i + 5
            Write-Host "[$num] $($customFiles[$i].name)"
        }
    }
    
    Write-Host ""
    Write-Host " --- OPERAZIONI BATCH ---" -ForegroundColor DarkGray
    Write-Host "[A] Installa TUTTI i programmi (Winget + Custom)"
    Write-Host "[R] Ricarica lista file da GitHub"
    Write-Host "[Q] Esci"
    Write-Host "========================================="
    
    $selection = Read-Host "Seleziona un'opzione"
    
    if ($selection -match '^[0-9]+$') {
        $val = [int]$selection
        if ($val -eq 1) { Install-WingetApp "Google.Chrome" }
        elseif ($val -eq 2) { Install-WingetApp "Mozilla.Firefox" }
        elseif ($val -eq 3) { Install-WingetApp "TheDocumentFoundation.LibreOffice" }
        elseif ($val -eq 4) { Install-WingetApp "7zip.7zip" }
        elseif ($val -ge 5 -and $val -lt (5 + $customFiles.Count)) {
            $index = $val - 5
            $fileObj = $customFiles[$index]
            $fileUrl = "$rawBase/$($fileObj.name)"
            $args = Get-SilentArgs $fileObj.name
            Install-CustomApp -downloadUrl $fileUrl -fileName $fileObj.name -arguments $args
        }
    } elseif ($selection -eq 'A' -or $selection -eq 'a') {
        Write-Host "Avvio installazione di massa..." -ForegroundColor Green
        Install-WingetApp "Google.Chrome"
        Install-WingetApp "Mozilla.Firefox"
        Install-WingetApp "TheDocumentFoundation.LibreOffice"
        Install-WingetApp "7zip.7zip"
        
        foreach ($fileObj in $customFiles) {
            $fileUrl = "$rawBase/$($fileObj.name)"
            $args = Get-SilentArgs $fileObj.name
            Install-CustomApp -downloadUrl $fileUrl -fileName $fileObj.name -arguments $args
        }
        Write-Host "Tutte le installazioni sono state completate!" -ForegroundColor Green
        Start-Sleep -Seconds 3
    } elseif ($selection -eq 'R' -or $selection -eq 'r') {
        Write-Host "Aggiornamento lista file..." -ForegroundColor Yellow
        $customFiles = Get-CustomFiles
    }

} until ($selection -eq 'Q' -or $selection -eq 'q')
