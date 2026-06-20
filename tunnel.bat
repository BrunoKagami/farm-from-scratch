@echo off
title Farm From Scratch - Tunnel
echo.
echo ========================================
echo   Farm From Scratch - Abrindo tunel
echo ========================================
echo.

where cloudflared >nul 2>&1
if %errorlevel% == 0 goto :start

echo Baixando cloudflared...
curl -L -o "%TEMP%\cloudflared.exe" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
if %errorlevel% neq 0 (
    echo ERRO: Falha ao baixar cloudflared. Verifique sua conexao.
    pause
    exit /b 1
)
set CLOUDFLARED=%TEMP%\cloudflared.exe
goto :start

:start
if not defined CLOUDFLARED set CLOUDFLARED=cloudflared

echo Inicie o jogo e clique Hospedar antes de continuar.
echo.
echo Quando aparecer a URL (wss://xxxx.trycloudflare.com),
echo copie e mande para seus amigos colarem no lobby do jogo.
echo.
echo Pressione CTRL+C para encerrar o tunnel.
echo ----------------------------------------
echo.

%CLOUDFLARED% tunnel --url http://localhost:7777
pause
