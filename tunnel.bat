@echo off
title Farm From Scratch - Tunnel
echo.
echo ========================================
echo   Farm From Scratch - Abrindo tunel
echo ========================================
echo.

set SCRIPT_DIR=%~dp0
set CF_LOCAL=%SCRIPT_DIR%cloudflared.exe

:: Verifica se já existe na pasta do jogo
if exist "%CF_LOCAL%" (
    set CLOUDFLARED=%CF_LOCAL%
    goto :start
)

:: Verifica se está no PATH
where cloudflared >nul 2>&1
if %errorlevel% == 0 (
    set CLOUDFLARED=cloudflared
    goto :start
)

echo Baixando cloudflared para a pasta do jogo...
echo.

:: Tenta com PowerShell (mais confiável que curl no Windows)
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile '%CF_LOCAL%'" 2>nul
if exist "%CF_LOCAL%" (
    echo Download concluido!
    set CLOUDFLARED=%CF_LOCAL%
    goto :start
)

:: Fallback: curl
curl -L -o "%CF_LOCAL%" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
if exist "%CF_LOCAL%" (
    set CLOUDFLARED=%CF_LOCAL%
    goto :start
)

echo ERRO: Nao foi possivel baixar o cloudflared.
echo Baixe manualmente em: https://github.com/cloudflare/cloudflared/releases/latest
echo e coloque o arquivo cloudflared.exe na mesma pasta deste bat.
pause
exit /b 1

:start
echo Inicie o jogo e clique Hospedar antes de continuar.
echo.
echo Quando aparecer a URL (https://xxxx.trycloudflare.com),
echo copie e mande para seus amigos colarem no lobby do jogo.
echo.
echo Pressione CTRL+C para encerrar o tunnel.
echo ----------------------------------------
echo.

"%CLOUDFLARED%" tunnel --url http://localhost:7777
pause
