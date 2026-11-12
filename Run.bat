@echo off
title Epson Resetter Suite [Created with love by rcwpt - @c.wijaya.t]
setlocal EnableDelayedExpansion

:: Check Administrator Privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [i] Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\EpsonResetter.ps1"
if %errorLevel% neq 0 (
    echo.
    echo Script finished.
    pause
)
