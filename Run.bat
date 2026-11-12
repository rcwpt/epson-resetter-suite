@echo off
title Epson Resetter All-In-One Suite Launcher
setlocal EnableDelayedExpansion

:: Check Administrator Privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Meminta hak akses Administrator...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\EpsonResetter.ps1"
if %errorLevel% neq 0 (
    echo.
    echo Script selesai.
    pause
)
