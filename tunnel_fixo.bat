@echo off
title Farm From Scratch - Tunnel Fixo
echo.
echo ========================================
echo   Farm From Scratch - Tunnel Fixo
echo ========================================
echo.

set SCRIPT_DIR=%~dp0
set CF_LOCAL=%SCRIPT_DIR%cloudflared.exe

if exist "%CF_LOCAL%" (
    set CLOUDFLARED=%CF_LOCAL%
) else (
    set CLOUDFLARED=cloudflared
)

echo Inicie o jogo e clique Hospedar antes de continuar.
echo.
echo URL fixa: https://farm.ninjautilitarios.com.br
echo Essa URL nao muda mais - manda ela pros seus amigos uma vez so.
echo.
echo Pressione CTRL+C para encerrar o tunnel.
echo ----------------------------------------
echo.

"%CLOUDFLARED%" tunnel run farm-from-scratch
pause
