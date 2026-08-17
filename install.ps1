# ==============================================================================
# SCRIPT PRINCIPALE DEPLOYMENT & UTILITY (install.ps1)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. VERIFICA E ELEVAZIONE PRIVILEGI AMMINISTRATORE
# ------------------------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[INFO] Richiesta elevazione privilegi di Amministratore..." -ForegroundColor Yellow
    
    # Riavvia lo script come Amministratore richiedendo il prompt UAC
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Imposta la directory temporanea come cartella di lavoro
Set-Location -Path $env:TEMP

# ------------------------------------------------------------------------------
# 2. CONFIGURAZIONE VARIABILI GLOBALI
# ------------------------------------------------------------------------------
$global:repoUser = "TUO_UTENTE"
$global:repoName = "TUO_REPO"
$global:branch   = "main"

$global:rawBase  = "https://raw.githubusercontent.com/$global:repoUser/$global:repoName/$global:branch"
$global:apiBase  = "https://api.github.com/repos/$global:repoUser/$global:repoName/$global:branch/contents"

# ------------------------------------------------------------------------------
# 3. CONTROLLO CONNETTIVITÀ DI RETE E API GITHUB
# ------------------------------------------------------------------------------
function Test-NetworkAndRepository {
    Write-Host "[INIT] Verifica connettivita di rete e stato GitHub..." -ForegroundColor Cyan

    # Test ping/connessione generale
    $pingTest = Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $pingTest) {
        Write-Host "`n[ERRORE CRITICO] Nessuna connessione a Internet rilevata." -ForegroundColor Red
        Write-Host "Verifica la connessione di rete e riprova." -ForegroundColor Yellow
        pause
        exit
    }

    # Test raggiungibilità dell'API GitHub
    try {
        $null = Invoke-RestMethod -Uri $global:apiBase -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "[OK] Connessione a GitHub riuscita.`n" -ForegroundColor Green
    } catch {
        Write-Host "`n[ERRORE CRITICO] Impossibile raggiungere la repository GitHub ($global:apiBase)." -ForegroundColor Red
        Write-Host "Verifica il nome utente, il repository o lo stato dei servizi GitHub." -ForegroundColor Yellow
        pause
        exit
    }
}

# Esegui il check prima di importare i moduli
Test-NetworkAndRepository

# ------------------------------------------------------------------------------
# 4. CARICAMENTO MODULI DALLA REPOSITORY
# ------------------------------------------------------------------------------
function Load-ModuleFromRepo {
    param ([string]$moduleName)
    $moduleUrl = "$global:rawBase/modules/$moduleName"
    try {
        Write-Host "[MODULES] Caricamento $moduleName..." -ForegroundColor DarkGray
        $scriptContent = Invoke-RestMethod -Uri $moduleUrl -UseBasicParsing -ErrorAction Stop
        Invoke-Expression $scriptContent
    } catch {
        Write-Host "[ERRORE] Impossibile caricare il modulo: $moduleName" -ForegroundColor Red
    }
}

# Carica i vari moduli del progetto
Load-ModuleFromRepo "module-winget.ps1"
Load-ModuleFromRepo "module-custom.ps1"
Load-ModuleFromRepo "module-tasks.ps1"
Load-ModuleFromRepo "module-utility.ps1"

# ------------------------------------------------------------------------------
# 5. INIZIALIZZAZIONE LISTE DATI DAI MODULI
# ------------------------------------------------------------------------------
Write-Host "`n[INIT] Sincronizzazione dati dalla repository..." -ForegroundColor Cyan
if (Get-Command Get-ModuleWingetList -ErrorAction SilentlyContinue) { $global:wingetList = Get-ModuleWingetList }
if (Get-Command Get-ModuleCustomList -ErrorAction SilentlyContinue) { $global:customList = Get-ModuleCustomList }
if (Get-Command Get-ModuleTasksList -ErrorAction SilentlyContinue)  { $global:taskList   = Get-ModuleTasksList }

# ------------------------------------------------------------------------------
# 6. MENU INTERATTIVO PRINCIPALE (MAIN LOOP)
# ------------------------------------------------------------------------------
while ($true) {
    Clear-Host
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "         SUITE STRUMENTI DI DEPLOYMENT & MANUTENZIONE            " -ForegroundColor White
    Write-Host "==================================================================" -ForegroundColor Cyan

    $index = 1

    # Mostra i menu dei singoli moduli
    if (Get-Command Show-ModuleWingetMenu -ErrorAction SilentlyContinue) { Show-ModuleWingetMenu ([ref]$index) }
    if (Get-Command Show-ModuleCustomMenu -ErrorAction SilentlyContinue) { Show-ModuleCustomMenu ([ref]$index) }
    if (Get-Command Show-ModuleTasksMenu -ErrorAction SilentlyContinue)  { Show-ModuleTasksMenu ([ref]$index) }
    if (Get-Command Show-ModuleUtilityMenu -ErrorAction SilentlyContinue){ Show-ModuleUtilityMenu ([ref]$index) }

    Write-Host "`n ------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " [0] ESCI" -ForegroundColor Red
    Write-Host "==================================================================" -ForegroundColor Cyan

    $choice = Read-Host "`nSeleziona un'opzione"

    if ($choice -eq "0") {
        Write-Host "`nUscita in corso..." -ForegroundColor Yellow
        break
    }

    # Conversione e smistamento dell'opzione inserita
    [int]$selectedOpt = -1
    if ([int]::TryParse($choice, [ref]$selectedOpt)) {
        
        # Logica di calcolo degli intervalli per la chiamata ai relativi moduli
        $wingetCount  = if ($global:wingetList) { $global:wingetList.Count } else { 0 }
        $customCount  = if ($global:customList) { $global:customList.Count } else { 0 }
        $tasksCount   = if ($global:taskList)   { $global:taskList.Count }   else { 0 }

        if ($selectedOpt -ge 1 -and $selectedOpt -le $wingetCount) {
            Invoke-ModuleWingetAction ($selectedOpt - 1)
        }
        elseif ($selectedOpt -gt $wingetCount -and $selectedOpt -le ($wingetCount + $customCount)) {
            Invoke-ModuleCustomAction ($selectedOpt - $wingetCount - 1)
        }
        elseif ($selectedOpt -gt ($wingetCount + $customCount) -and $selectedOpt -le ($wingetCount + $customCount + $tasksCount)) {
            Invoke-ModuleTasksAction ($selectedOpt - $wingetCount - $customCount - 1)
        }
        else {
            # Gestione opzioni aggiuntive (es. Utility)
            if (Get-Command Invoke-ModuleUtilityAction -ErrorAction SilentlyContinue) {
                Invoke-ModuleUtilityAction $selectedOpt
            } else {
                Write-Host "`n[!] Opzione non valida." -ForegroundColor Red
            }
        }
    } else {
        Write-Host "`n[!] Inserisci un numero valido." -ForegroundColor Red
    }

    Write-Host "`nPremere un tasto per tornare al menu..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
