# ==============================================================================
# SCRIPT INSTALLAZIONE SOFTWARE SCUOLA
# Repository: https://github.com/SimoGHcoder/WorkInstaller
# ==============================================================================

# 1. Forza l'uso di TLS 1.2 per evitare errori di download da GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Richiesta e verifica privilegi di Amministratore
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Riavvio dello script con privilegi di Amministratore..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 3. Configurazione indirizzo base del repository Raw
$baseUrl = "https://raw.githubusercontent.com/SimoGHcoder/WorkInstaller/refs/heads/main"

# Funzione per mostrare il menu principale
function Show-Menu {
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
    Write-Host " --- SOFTWARE PERSONALIZZATI / CUSTOM ---" -ForegroundColor DarkGray
    Write-Host "[5] Software Personalizzato 1 (.exe)"
    Write-Host "[6] Software Personalizzato 2 (.msi)"
    Write-Host ""
    Write-Host " --- OPERAZIONI BATCH ---" -ForegroundColor DarkGray
    Write-Host "[A] Installa TUTTI i programmi base"
    Write-Host "[Q] Esci"
    Write-Host "========================================="
}

# Funzione per installazione software da Winget
function Install-WingetApp ([string]$id) {
    Write-Host "--> Installazione di $id tramite Winget..." -ForegroundColor Yellow
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements
}

# Funzione per download ed esecuzione di installer custom
function Install-CustomApp ([string]$downloadUrl, [string]$fileName, [string]$arguments) {
    $outPath = "$env:TEMP\$fileName"
    
    Write-Host "--> Download di $fileName in corso..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outPath -UseBasicParsing
    
    Write-Host "--> Esecuzione installazione per $fileName..." -ForegroundColor Yellow
    $process = Start-Process -FilePath $outPath -ArgumentList $arguments -Wait -PassThru
    
    # Pulizia file temporaneo scaricato
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    Write-Host "--> Completato." -ForegroundColor Green
}

# Ciclo principale del menu
do {
    Show-Menu
    $selection = Read-Host "Seleziona un'opzione"
    
    switch ($selection) {
        '1' { Install-WingetApp "Google.Chrome" }
        '2' { Install-WingetApp "Mozilla.Firefox" }
        '3' { Install-WingetApp "TheDocumentFoundation.LibreOffice" }
        '4' { Install-WingetApp "7zip.7zip" }
        '5' { 
            # Esempio file presente dentro la cartella 'installer' su GitHub
            $url = "$baseUrl/installer/ProgrammaCustom.exe"
            Install-CustomApp -downloadUrl $url -fileName "ProgrammaCustom.exe" -arguments "/S"
        }
        '6' { 
            # Esempio file presente nelle Releases di GitHub
            $url = "https://github.com/SimoGHcoder/WorkInstaller/releases/download/v1.0/SetupSpeciale.msi"
            Install-CustomApp -downloadUrl $url -fileName "SetupSpeciale.msi" -arguments "/qn /norestart"
        }
        'A' {
            Write-Host "Avvio installazione automatizzata di massa..." -ForegroundColor Green
            Install-WingetApp "Google.Chrome"
            Install-WingetApp "Mozilla.Firefox"
            Install-WingetApp "TheDocumentFoundation.LibreOffice"
            Install-WingetApp "7zip.7zip"
            
            Write-Host "Tutte le installazioni sono state completate!" -ForegroundColor Green
            Start-Sleep -Seconds 3
        }
    }
} until ($selection -eq 'Q' -or $selection -eq 'q')
