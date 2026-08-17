# ==============================================================================
# MODULO 2: INSTALLER CUSTOM (INSTALLAZIONE MANUALE INTERATTIVA)
# ==============================================================================

function global:Get-ModuleCustomList {
    $list = @()
    $url = "$global:apiBase/installer"
    try {
        $items = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        foreach ($item in $items) {
            # Filtro: esclude le cartelle e i file .gitkeep
            if ($item.type -eq "file" -and $item.name -ne ".gitkeep") {
                $list += [PSCustomObject]@{
                    Name        = $item.name
                    DownloadUrl = $item.download_url
                }
            }
        }
    } catch {
        # Cartella vuota o non presente
    }
    return $list
}

function global:Show-ModuleCustomMenu ([ref]$startIndex) {
    Write-Host "`n --- 2. INSTALLER CUSTOM (MANUALE) ---" -ForegroundColor DarkGray
    if ($global:customList.Count -eq 0) {
        Write-Host " (Nessun installer presente nella cartella installer/)" -ForegroundColor Yellow
        return
    }
    foreach ($item in $global:customList) {
        Write-Host " [$($startIndex.Value)] $($item.Name)"
        $startIndex.Value++
    }
}

function global:Invoke-ModuleCustomAction ([int]$index) {
    if ($index -ge 0 -and $index -lt $global:customList.Count) {
        $item = $global:customList[$index]
        
        $tempFolder = "$env:TEMP\WorkInstaller"
        if (-not (Test-Path $tempFolder)) { New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null }
        
        $destinationPath = Join-Path $tempFolder $item.Name

        Write-Host "`n --> [Custom Manual] Download di $($item.Name)..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $item.DownloadUrl -OutFile $destinationPath -UseBasicParsing -ErrorAction Stop
            Write-Host " --> Download completato. Avvio procedura guidata interattiva..." -ForegroundColor Green
            
            # Esecuzione SENZA argomenti silent: si apre la finestra del setup standard.
            # -Wait blocca lo script fino al termine dell'installazione manuale.
            Start-Process -FilePath $destinationPath -Wait
            
            Write-Host " [OK] Installazione manuale di $($item.Name) completata." -ForegroundColor Green
        } catch {
            Write-Host " [!] Errore durante il download o l'avvio di $($item.Name): $_" -ForegroundColor Red
        } finally {
            # Pulizia file temporaneo scaricato
            if (Test-Path $destinationPath) { Remove-Item $destinationPath -Force -ErrorAction SilentlyContinue }
        }
    }
}
