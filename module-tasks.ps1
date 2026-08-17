function global:Get-ModuleTasksList {
    $list = @()
    $url = "$global:apiBase/tasks"
    try {
        $items = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        foreach ($item in $items) {
            if ($item.type -eq "file") {
                $list += [PSCustomObject]@{
                    Name        = $item.name
                    DownloadUrl = $item.download_url
                }
            }
        }
    } catch {
        # Fallback se la cartella tasks/ non esiste o è vuota
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

function global:Invoke-ModuleTasksAction ([int]$index) {
    if ($index -ge 0 -and $index -lt $global:taskList.Count) {
        $item = $global:taskList[$index]
        Execute-BatchTask -downloadUrl $item.DownloadUrl -fileName $item.Name
    }
}
