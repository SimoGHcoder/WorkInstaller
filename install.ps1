# ==========================================
# SCRIPT INSTALLAZIONE SOFTWARE SCUOLA
# ==========================================

# Verfica e richiesta privilegi di Amministratore
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Imposta il link del tuo repo GitHub per scaricare gli installer personalizzati
$repoRawUrl = "https://raw.githubusercontent.com/TUO-UTENTE/TUO-REPO/main"

function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "      GESTIONE INSTALLAZIONI SCUOLA      " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "[1] Google Chrome (Winget)"
    Write-Host "[2] Mozilla Firefox (Winget)"
    Write-Host "[3] LibreOffice (Winget)"
    Write-Host "[4] 7-Zip (Winget)"
    Write-Host "-----------------------------------------"
    Write-Host "[5] Programma Personalizzato 1 (.exe/.msi)"
    Write-Host "[6] Programma Personalizzato 2 (.exe/.msi)"
    Write-Host "-----------------------------------------"
    Write-Host "[A] Installa TUTTI i programmi base"
    Write-Host "[Q] Esci"
    Write-Host "========================================="
}

function Install-WingetApp ($id) {
    Write-Host "Installazione di $id tramite Winget..." -ForegroundColor Yellow
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements
}

function Install-CustomApp ($fileName, $arguments) {
    $outPath = "$env:TEMP\$fileName"
    $fileUrl = "$repoRawUrl/installer/$fileName"
    
    Write-Host "Download di $fileName in corso..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $fileUrl -OutFile $outPath
    
    Write-Host "Installazione di $fileName..." -ForegroundColor Yellow
    Start-Process -FilePath $outPath -ArgumentList $arguments -Wait
    
    Remove-Item $outPath -Force
}

do {
    Show-Menu
    $selection = Read-Host "Seleziona un'opzione"
    
    switch ($selection) {
        '1' { Install-WingetApp "Google.Chrome" }
        '2' { Install-WingetApp "Mozilla.Firefox" }
        '3' { Install-WingetApp "TheDocumentFoundation.LibreOffice" }
        '4' { Install-WingetApp "7zip.7zip" }
        '5' { 
            # Esempio per installer .exe silenzioso (modifica gli argomenti in base al programma, es: /S, /quiet)
            Install-CustomApp "MioSoftwareCustom.exe" "/S" 
        }
        '6' { 
            # Esempio per installer .msi
            Install-CustomApp "MioSetup.msi" "/qn /norestart" 
        }
        'A' {
            Write-Host "Avvio installazione completa..." -ForegroundColor Green
            Install-WingetApp "Google.Chrome"
            Install-WingetApp "Mozilla.Firefox"
            Install-WingetApp "TheDocumentFoundation.LibreOffice"
            Install-WingetApp "7zip.7zip"
            Install-CustomApp "MioSoftwareCustom.exe" "/S"
            Write-Host "Installazione completata!" -ForegroundColor Green
            Start-Sleep -Seconds 3
        }
    }
} until ($selection -eq 'Q' -or $selection -eq 'q')