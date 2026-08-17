@echo off
setlocal

echo ============================================================
echo           RIPRISTINO E PULIZIA CODA DI STAMPA
echo ============================================================
echo.

:: 1. Arresto del servizio Spooler di stampa
echo [1/4] Arresto del servizio Spooler di stampa (spoolsv)...
net stop spooler /y >nul 2>&1

:: 2. Eliminazione dei file temporanei bloccati nella coda
echo [2/4] Svuotamento della cartella dei file temporanei...
del /Q /F /S "%systemroot%\System32\Spool\Printers\*.*" >nul 2>&1

:: 3. Riavvio del servizio Spooler
echo [3/4] Avvio del servizio Spooler di stampa...
net start spooler >nul 2>&1

:: 4. Verifica dello stato finale
echo [4/4] Verifica dello stato del servizio...
sc query spooler | findstr /I "RUNNING" >nul
if %errorlevel% equ 0 (
    echo.
    echo [OK] Servizio Spooler riavviato correttamente e coda svuotata!
) else (
    echo.
    echo [ATTENZIONE] Si e verificato un problema nell'avvio dello Spooler.
)

echo.
pause
