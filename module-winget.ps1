function global:Get-ModuleWingetList {
    $list = @()
    $url = "$global:rawBase/winget-apps.txt"
    try {
        $content = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        $lines = $content -split "`r?\n" | Where-Object { $_ -match '\|' }
        foreach ($line in $lines) {
            $parts = $line.Split('|')
            if ($parts.Count -ge 2) {
                $list += [PSCustomObject]@{
                    Name = $parts[0].Trim()
                    Id   = $parts[1].Trim()
                }
            }
        }
    } catch {
        # Fallback se il file non esiste ancora
    }
    return $list
}

function global:Show-ModuleWingetMenu ([ref]$startIndex) {
    Write-Host " --- 1. SOFTWARE STANDARD (WINGET) ---" -ForegroundColor DarkGray
    if ($global:wingetList.Count -eq 0) {
        Write-Host " (Nessuna app trovata in winget-apps.txt)" -ForegroundColor Yellow
        return
    }
    foreach ($item in $global:wingetList) {
        Write-Host " [$($startIndex.Value)] $($item.Name)"
        $startIndex.Value++
    }
}

function global:Invoke-ModuleWingetAction ([int]$index) {
    if ($index -ge 0 -and $index -lt $global:wingetList.Count) {
        $item = $global:wingetList[$index]
        Install-WingetApp -id $item.Id -name $item.Name
    }
}
