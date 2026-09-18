@echo off
echo ============================================================
echo   MINER CLC - SCRIPT DE DESPLIEGUE EJECUTABLE (ANEXO A)
echo ============================================================
echo [1/4] Verificando entorno de compilacion Flutter y dependencias...

cd /d "%~dp0.."

call "C:\Users\Asus Vivobook\develop\flutter\bin\flutter.bat" pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Fallo al obtener paquetes de Flutter.
    pause
    exit /b 1
)

echo.
echo [2/4] Ejecutando analisis de codigo estatico...
call "C:\Users\Asus Vivobook\develop\flutter\bin\flutter.bat" analyze --no-fatal-infos
if %ERRORLEVEL% NEQ 0 (
    echo [ALERTA] Se encontraron observaciones en el analisis estatico.
)

echo.
echo [3/4] Compilando ejecutable nativo para Windows (Release)...
call "C:\Users\Asus Vivobook\develop\flutter\bin\flutter.bat" build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Fallo en la compilacion para Windows.
    pause
    exit /b 1
)

echo.
echo [4/4] Verificando binario generado...
if exist "build\windows\x64\runner\Release\miner_clc.exe" (
    echo [EXITO] Ejecutable generado correctamente en:
    echo        build\windows\x64\runner\Release\miner_clc.exe
) else (
    echo [AVISO] Revise la carpeta build\windows para ubicar el ejecutable.
)

echo ============================================================
echo   DESPLIEGUE EJECUTABLE COMPLETADO (ANEXO A)
echo ============================================================
pause
