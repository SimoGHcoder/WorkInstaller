# ==============================================================================
# MODULO 4: OPERAZIONI MASSIVE E UTILITY
# ==============================================================================

function global:Show-ModuleUtilityMenu {
    Write-Host ""
    Write-Host " --- 4. OPERAZIONI MASSIVE E UTILITY ---" -ForegroundColor DarkGray
    Write-Host "[W] Installa TUTTE le app Winget"
    Write-Host "[M] SELEZIONE MULTIPLA PERSONALIZZATA"
    Write-Host "[R] Ricarica moduli da GitHub"
    Write-Host "[Q] Esci"
    Write-Host "========================================="
}

function global:Show-ModuleUtilityMultiSelect {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   INSTALLAZIONE MASSIVA PERSONALIZZATA  " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $allSoftware = @()
    $idx = 1

    Write-Host "--- SOFTWARE DISPONIBILI ---" -ForegroundColor DarkGray
    foreach ($app in $global:wingetList) {
        Write-Host "[$idx] [Winget] $($app.Name)"
        $allSoftware += [PSCustomObject]@{ Number = $idx; Object = $app; Type = "Winget" }
        $idx++
    }
    foreach ($file in $global:customList) {
        Write-Host "[$idx] [Custom] $($file.Name)"
        $allSoftware += [PSCustomObject]@{ Number = $idx; Object = $file; Type = "Custom" }
        $idx++
    }

    if ($allSoftware.Count -eq 0) {
        Write-Host "Nessun software disponibile." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    Write-Host ""
    Write-Host "Inserisci i numeri separati da virgola (es: 1,3,5)" -ForegroundColor Yellow
    $inputRaw = Read-Host "Selezione (lascia vuoto per annullare)"

    if ([string]::IsNullOrWhiteSpace($inputRaw)) { return }

    $selectedIndices = $inputRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' } | ForEach-Object { [int]$_ }

    Write-Host ""
    Write-Host "Avvio installazione selezionata..." -ForegroundColor Green

    foreach ($num in $selectedIndices) {
        $item = $allSoftware | Where-Object { $_.Number -eq $num }
        if ($item) {
            if ($item.Type -eq "Winget") {
                Install-WingetApp -id $item.Object.Id -name $item.Object.Name
            }
            elseif ($item.Type -eq "Custom") {
                Install-CustomApp -downloadUrl $item.Object.DownloadUrl -fileName $item.Object.Name
            }
        }
    }

    Write-Host ""
    Write-Host "Installazioni selezionate completate!" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

function global:Invoke-ModuleUtilityAction ([string]$code) {
    if ([string]::IsNullOrWhiteSpace($code)) { return }

    switch ($code.Trim().ToUpper()) {
        'W' {
            Write-Host "Avvio installazione di massa Winget..." -ForegroundColor Green
            foreach ($app in $global:wingetList) { Install-WingetApp -id $app.Id -name $app.Name }
            Write-Host "Installazioni completate!" -ForegroundColor Green
            Start-Sleep -Seconds 3
        }
        'M' {
            Show-ModuleUtilityMultiSelect
        }
        'R' {
            Reload-All
        }
    }
}
