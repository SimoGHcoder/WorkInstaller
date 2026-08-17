# ==============================================================================
# MODULO 3: OPERAZIONI BATCH E SCRIPT
# ==============================================================================

function Get-ModuleTasksList {
    try {
        $res = Invoke-RestMethod -Uri "$global:apiBase/tasks" -Method Get -Headers @{ "User-Agent" = "PowerShell" } -ErrorAction Stop
        return $res | Where-Object { $_.type -eq "file" -and ($_.name -like "*.ps1" -or $_.name -like "*.bat") }
    } catch { return @() }
}

function Show-ModuleTasksMenu ([ref]$startIndex) {
    Write-Host ""
    Write-Host " --- 3. OPERAZIONI BATCH (TASKS/) ---" -ForegroundColor DarkGray
    if ($global:taskList.Count -eq 0) {
        Write-Host " (Nessuno script trovato nella cartella 'tasks')" -ForegroundColor Gray
    } else {
        foreach ($task in $global:taskList) {
            Write-Host "[$($startIndex.Value)] $($task.name)"
            $startIndex.Value++
        }
    }
}

function Invoke-ModuleTasksAction ([int]$index) {
    $task = $global:taskList[$index]
    if ($task) {
        Execute-BatchTask -downloadUrl "$global:rawBase/tasks/$($task.name)" -fileName $task.name
    }
}
