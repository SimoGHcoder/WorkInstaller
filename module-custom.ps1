# ==============================================================================
# MODULO 2: INSTALLER CUSTOM
# ==============================================================================

function Get-ModuleCustomList {
    try {
        $res = Invoke-RestMethod -Uri "$global:apiBase/installer" -Method Get -Headers @{ "User-Agent" = "PowerShell" } -ErrorAction Stop
        $files = $res | Where-Object { $_.type -eq "file" -and ($_.name -like "*.exe" -or $_.name -like "*.msi") }
        $installers = @()
        foreach ($f in $files) {
            $installers += [PSCustomObject]@{ Name = $f.name; DownloadUrl = "$global:rawBase/installer/$($f.name)"; Type = "Custom" }
        }
        return $installers
    } catch { return @() }
}

function Show-ModuleCustomMenu ([ref]$startIndex) {
    Write-Host ""
    Write-Host " --- 2. INSTALLER CUSTOM (INSTALLER/) ---" -ForegroundColor DarkGray
    if ($global:customList.Count -eq 0) {
        Write-Host " (Nessun file .exe/.msi nella cartella 'installer')" -ForegroundColor Gray
    } else {
        foreach ($file in $global:customList) {
            Write-Host "[$($startIndex.Value)] $($file.Name)"
            $startIndex.Value++
        }
    }
}

function Invoke-ModuleCustomAction ([int]$index) {
    $file = $global:customList[$index]
    if ($file) {
        Install-CustomApp -downloadUrl $file.DownloadUrl -fileName $file.Name
    }
}
