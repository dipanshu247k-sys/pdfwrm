@echo off
TITLE Scoop Tool Installer

:: 1. Check if Scoop is already installed
where scoop >nul 2>nul
if %errorlevel% neq 0 (
    echo Scoop not found. Installing Scoop...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (iwr -UseBasicParsing get.scoop.sh)"
) else (
    echo Scoop is already installed.
)

:: 2. Refresh environment variables for the current session
:: This allows the script to use 'scoop' immediately after installing it
set "PATH=%USERPROFILE%\scoop\shims;%PATH%"

:: 3. Update Scoop to ensure the latest manifests
echo Updating Scoop...
call scoop update

:: 4. Install poppler, img2pdf, and fzf
echo Installing tools: poppler, img2pdf, fzf...
call scoop install poppler img2pdf fzf

echo.
echo All tools have been installed!
echo You may need to restart your terminal to use them.
pause
