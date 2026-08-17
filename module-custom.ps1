function global:Get-ModuleCustomList {
    $list = @()
    $url = "$global:apiBase/installer"
    try {
        $items = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        foreach ($item in $items) {
            # Filtro: controlla che sia un file e che NON sia .gitkeep
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
    Write-Host "`n --- 2. INSTALLER CUSTOM (INSTALLER/) ---" -ForegroundColor DarkGray
    if ($global:customList.Count -eq 0) {
        Write-Host " (Nessun file presente nella cartella installer/)" -ForegroundColor Yellow
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
        Install-CustomApp -downloadUrl $item.DownloadUrl -fileName $item.Name
    }
}
