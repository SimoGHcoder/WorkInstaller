# ==============================================================================
# MODULO 1: SOFTWARE STANDARD WINGET
# ==============================================================================

function Get-ModuleWingetList {
    try {
        $content = Invoke-RestMethod -Uri "$global:rawBase/winget-apps.txt" -ErrorAction Stop
        $lines = $content -split "`r?`n" | Where-Object { $_ -match '\|' -and -not $_.StartsWith("#") }
        $apps = @()
        foreach ($line in $lines) {
            $parts = $line.Split('|')
            $apps += [PSCustomObject]@{ Name = $parts[0].Trim(); Id = $parts[1].Trim(); Type = "Winget" }
        }
        return $apps
    } catch { return @() }
}

function Show-ModuleWingetMenu ([ref]$startIndex) {
    Write-Host " --- 1. SOFTWARE STANDARD (WINGET) ---" -ForegroundColor DarkGray
    if ($global:wingetList.Count -eq 0) {
        Write-Host " (Nessuna app definita in winget-apps.txt)" -ForegroundColor Gray
    } else {
        foreach ($app in $global:wingetList) {
            Write-Host "[$($startIndex.Value)] $($app.Name)"
            $startIndex.Value++
        }
    }
}

function Invoke-ModuleWingetAction ([int]$index) {
    $app = $global:wingetList[$index]
    if ($app) {
        Install-WingetApp -id $app.Id -name $app.Name
    }
}
