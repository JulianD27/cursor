@echo off
echo ============================================================
echo   MINER CLC - EJECUTAR RESPALDO DE BASE DE DATOS (ANEXO A)
echo ============================================================
cd /d "%~dp0.."
python scripts/backup_database.py
if %ERRORLEVEL% EQU 0 (
    echo.
    echo [EXITO] El respaldo fue generado y registrado en auditoria_logs.
) else (
    echo.
    echo [ERROR] Hubo un problema al generar el respaldo.
)
pause
