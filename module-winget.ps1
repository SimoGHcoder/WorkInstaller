# ==============================================================================
# MODULO 1: GESTIONE APP WINGET (LETTURA DA WINGET-APPS.TXT)
# ==============================================================================

function global:Get-ModuleWingetList {
    $list = @()
    $url = "$global:rawBase/winget-apps.txt"
    
    try {
        # Scarica il file winget-apps.txt dal repository GitHub
        $content = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        
        # Divide il contenuto riga per riga
        $lines = $content -split "`r?\n"
        
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            
            # Ignora righe vuote o commenti
            if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
                continue
            }
            
            # Parsing "ID | Nome" oppure solo "ID"
            if ($trimmed -like "*|*") {
                $parts = $trimmed -split "\|"
                $appId = $parts[0].Trim()
                $appName = $parts[1].Trim()
            } else {
                $appId = $trimmed
                $appName = $trimmed
            }
            
            $list += [PSCustomObject]@{
                Id   = $appId
                Name = $appName
            }
        }
    } catch {
        Write-Host " [!] Impossibile scaricare o leggere winget-apps.txt da GitHub." -ForegroundColor Red
    }
    
    return $list
}

function global:Show-ModuleWingetMenu ([ref]$startIndex) {
    Write-Host " --- 1. SOFTWARE STANDARD WINGET (SILENT) ---" -ForegroundColor DarkGray
    if ($global:wingetList.Count -eq 0) {
        Write-Host " (Nessuna app presente in winget-apps.txt o file non trovato)" -ForegroundColor Yellow
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
            Write-Host "`n --> [Winget Silent] Avvio installazione di: $($app.Name) ($($app.Id))..." -ForegroundColor Cyan
            
            # Esecuzione silente automatica
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
