@echo off
title Farm From Scratch - Servidor Dedicado
echo.
echo ========================================
echo   Farm From Scratch - Servidor Dedicado
echo ========================================
echo.

set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
set GODOT_EXE=C:\Users\bruno\Documents\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe

if not exist "%GODOT_EXE%" (
    echo ERRO: Nao encontrei o Godot em "%GODOT_EXE%".
    echo Edite a variavel GODOT_EXE neste arquivo com o caminho correto.
    pause
    exit /b 1
)

echo Iniciando servidor headless na porta 7777...
echo Abra o tunnel.bat em outra janela para gerar o link.
echo Pressione CTRL+C para encerrar.
echo ----------------------------------------
echo.

"%GODOT_EXE%" --headless --path "%SCRIPT_DIR%"
pause
