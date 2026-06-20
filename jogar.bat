@echo off
title Farm From Scratch
echo Iniciando Farm From Scratch...
"C:\Users\bruno\Documents\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\bruno\Documents\farm-from-scratch"
if %errorlevel% neq 0 (
    echo.
    echo ERRO ao iniciar. Codigo: %errorlevel%
    pause
)
