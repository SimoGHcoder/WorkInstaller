# ==============================================================================
# MODULO 1: GESTIONE APP WINGET (INSTALLAZIONE AUTOMATICA SILENTE)
# ==============================================================================

function global:Get-ModuleWingetList {
    # Lista di app Winget standard predefinite per l'ambiente scolastico/lab
    return @(
        [PSCustomObject]@{ Id = "7zip.7zip"; Name = "7-Zip" },
        [PSCustomObject]@{ Id = "VideoLAN.VLC"; Name = "VLC Media Player" },
        [PSCustomObject]@{ Id = "Google.Chrome"; Name = "Google Chrome" },
        [PSCustomObject]@{ Id = "Mozilla.Firefox"; Name = "Mozilla Firefox" },
        [PSCustomObject]@{ Id = "Foxit.PDFReader"; Name = "Foxit PDF Reader" },
        [PSCustomObject]@{ Id = "Notepad++.Notepad++"; Name = "Notepad++" },
        [PSCustomObject]@{ Id = "Oracle.JavaRuntimeEnvironment"; Name = "Java JRE" }
    )
}

function global:Show-ModuleWingetMenu ([ref]$startIndex) {
    Write-Host " --- 1. SOFTWARE STANDARD WINGET (SILENT) ---" -ForegroundColor DarkGray
    if ($global:wingetList.Count -eq 0) {
        Write-Host " (Nessuna app Winget configurata)" -ForegroundColor Yellow
        return
    }
    foreach ($item in $global:wingetList) {
        Write-Host " [$($startIndex.Value)] $($item.Name)"
        $startIndex.Value++
    }
}

function global:Invoke-ModuleWingetAction ([string]$inputSelection) {
    if ([string]::IsNullOrWhiteSpace($inputSelection)) { return }

    # Converte l'input (es. "1,3,5" o "1 3 5") in indici numerici validi
    $indexes = $inputSelection -split '[\s,]' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ - 1 }

    if ($indexes.Count -eq 0) {
        Write-Host " [!] Selezione non valida." -ForegroundColor Yellow
        return
    }

    foreach ($idx in $indexes) {
        if ($idx -ge 0 -and $idx -lt $global:wingetList.Count) {
            $app = $global:wingetList[$idx]
            Write-Host "`n --> [Winget Silent] Avvio installazione di: $($app.Name)..." -ForegroundColor Cyan
            
            # Esecuzione silente senza interazione
            winget install --id $app.Id --silent --accept-source-agreements --accept-package-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host " [OK] $($app.Name) installato con successo." -ForegroundColor Green
            } else {
                Write-Host " [!] Installazione di $($app.Name) completata con codice: $LASTEXITCODE" -ForegroundColor Yellow
            }
        } else {
            Write-Host " [!] Indice $($idx + 1) fuori scala, ignorato." -ForegroundColor Yellow
        }
    }
}
