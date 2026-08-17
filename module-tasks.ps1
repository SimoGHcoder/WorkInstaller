# ==============================================================================
# MODULO 3: OPERAZIONI BATCH E SCRIPT (TASKS/)
# ==============================================================================

function global:Get-ModuleTasksList {
    $list = @()
    $url = "$global:apiBase/tasks"
    try {
        $items = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        foreach ($item in $items) {
            # Filtro: esclude cartelle e file .gitkeep
            if ($item.type -eq "file" -and $item.name -ne ".gitkeep") {
                $list += [PSCustomObject]@{
                    Name        = $item.name
                    DownloadUrl = $item.download_url
                }
            }
        }
    } catch {
        # Cartella vuota o non raggiungibile
    }
    return $list
}

function global:Show-ModuleTasksMenu ([ref]$startIndex) {
    Write-Host "`n --- 3. OPERAZIONI BATCH (TASKS/) ---" -ForegroundColor DarkGray
    if ($global:taskList.Count -eq 0) {
        Write-Host " (Nessuno script presente nella cartella tasks/)" -ForegroundColor Yellow
        return
    }
    foreach ($item in $global:taskList) {
        Write-Host " [$($startIndex.Value)] $($item.Name)"
        $startIndex.Value++
    }
}

function global:Execute-BatchTask {
    param (
        [string]$downloadUrl,
        [string]$fileName
    )
    
    try {
        Write-Host "`n[TASKS] Download ed esecuzione di: $fileName..." -ForegroundColor Cyan
        
        # 1. Salva il file nella cartella TEMP locale per evitare problemi di permessi/percorso
        $tempFilePath = Join-Path $env:TEMP $fileName
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFilePath -UseBasicParsing
        
        # 2. Rileva l'estensione per stabilire il metodo di esecuzione
        $extension = [System.IO.Path]::GetExtension($fileName).ToLower()
        
        if ($extension -eq ".ps1") {
            # Esecuzione script PowerShell in un processo dedicato
            $proc = Start-Process powershell.exe `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempFilePath`"" `
                -WorkingDirectory $env:TEMP `
                -NoNewWindow:$false `
                -Wait `
                -PassThru
        }
        else {
            # Esecuzione script Batch (.cmd / .bat) tramite CMD in una finestra dedicata
            $proc = Start-Process "cmd.exe" `
                -ArgumentList "/c `"$tempFilePath`"" `
                -WorkingDirectory $env:TEMP `
                -NoNewWindow:$false `
                -Wait `
                -PassThru
        }

        # 3. Pulizia del file temporaneo scaricato
        if (Test-Path $tempFilePath) {
            Remove-Item -Path $tempFilePath -Force -ErrorAction SilentlyContinue
        }

        if ($proc.ExitCode -eq 0) {
            Write-Host "[OK] Completato con successo: $fileName" -ForegroundColor Green
        } else {
            Write-Host "[WARN] $fileName terminato con codice uscita: $($proc.ExitCode)" -ForegroundColor Yellow
        }

    } catch {
        Write-Host "[ERRORE] Impossibile eseguire $fileName : $_" -ForegroundColor Red
    }
}

function global:Invoke-ModuleTasksAction ([int]$index) {
    if ($index -ge 0 -and $index -lt $global:taskList.Count) {
        $item = $global:taskList[$index]
        Execute-BatchTask -downloadUrl $item.DownloadUrl -fileName $item.Name
    }
}
