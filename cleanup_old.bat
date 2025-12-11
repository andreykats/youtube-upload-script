@echo off
setlocal enabledelayedexpansion

REM ============================================
REM YouTube Upload Script - Old Installation Cleanup
REM ============================================
REM This script removes old youtubeuploader installations
REM before reinstalling with the new directory name.
REM ============================================

cls
echo.
echo ============================================
echo YouTube Upload Script - Cleanup Old Installation
echo ============================================
echo.
echo This will remove the old "youtubeuploader" installation
echo and prepare for reinstall with new directory name.
echo.

REM Check for existing installation
where youtubeuploader >nul 2>&1
set "CHECK_ERR=!errorlevel!"
if !CHECK_ERR! neq 0 (
    echo [INFO] No existing youtubeuploader installation found in PATH.
    echo.
    echo You can proceed with running install.bat
    pause
    exit /b 0
)

echo [FOUND] Existing installation detected:
echo.
where youtubeuploader
echo.
echo.

REM Ask user to confirm
choice /C YN /M "Do you want to remove this installation"
set "CHOICE_ERR=!errorlevel!"
if !CHOICE_ERR!==2 (
    echo.
    echo [CANCELLED] Cleanup cancelled by user.
    pause
    exit /b 0
)

echo.
echo [INFO] Starting cleanup...
echo.

REM Check if running as admin
net session >nul 2>&1
set "ADMIN_CHK=!errorlevel!"
if !ADMIN_CHK! == 0 (
    set "IS_ADMIN=1"
    echo [INFO] Running with administrator privileges
) else (
    set "IS_ADMIN=0"
    echo [INFO] Running without administrator privileges
)
echo.

REM Try to remove from system PATH (requires admin)
if !IS_ADMIN!==1 (
    echo [INFO] Removing from system PATH...
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do (
        set "SYSTEM_PATH=%%b"
        set "NEW_SYSTEM_PATH=!SYSTEM_PATH:C:\Program Files\youtubeuploader;=!"
        if not "!SYSTEM_PATH!"=="!NEW_SYSTEM_PATH!" (
            setx /M PATH "!NEW_SYSTEM_PATH!" >nul 2>&1
            if !errorlevel! == 0 (
                echo [SUCCESS] Removed from system PATH
            ) else (
                echo [WARNING] Could not modify system PATH
            )
        )
    )
)

REM Remove from user PATH
echo [INFO] Removing from user PATH...
for /f "skip=2 tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do (
    set "USER_PATH=%%b"
    set "NEW_USER_PATH=!USER_PATH:%LOCALAPPDATA%\youtubeuploader;=!"
    if not "!USER_PATH!"=="!NEW_USER_PATH!" (
        setx PATH "!NEW_USER_PATH!" >nul 2>&1
        if !errorlevel! == 0 (
            echo [SUCCESS] Removed from user PATH
        ) else (
            echo [WARNING] Could not modify user PATH
        )
    )
)
echo.

REM Delete Program Files directory (requires admin)
if !IS_ADMIN!==1 (
    if exist "C:\Program Files\youtubeuploader" (
        echo [INFO] Deleting C:\Program Files\youtubeuploader...
        rmdir /s /q "C:\Program Files\youtubeuploader" 2>nul
        if !errorlevel! == 0 (
            echo [SUCCESS] Deleted C:\Program Files\youtubeuploader
        ) else (
            echo [WARNING] Could not delete C:\Program Files\youtubeuploader
            echo [HINT] Try running this script as administrator
        )
        echo.
    )
)

REM Delete user AppData directory
if exist "%LOCALAPPDATA%\youtubeuploader" (
    echo [INFO] Deleting %LOCALAPPDATA%\youtubeuploader...
    rmdir /s /q "%LOCALAPPDATA%\youtubeuploader" 2>nul
    if !errorlevel! == 0 (
        echo [SUCCESS] Deleted %LOCALAPPDATA%\youtubeuploader
    ) else (
        echo [WARNING] Could not delete %LOCALAPPDATA%\youtubeuploader
    )
    echo.
)

REM Final check
where youtubeuploader >nul 2>&1
set "FINAL_CHK=!errorlevel!"
if !FINAL_CHK! neq 0 (
    echo ============================================
    echo [SUCCESS] Cleanup Complete!
    echo ============================================
    echo.
    echo Old installation has been removed.
    echo.
    echo Next steps:
    echo   1. Close this window
    echo   2. Open a NEW Command Prompt
    echo   3. Run: install.bat
    echo.
    echo This will install to the new directory:
    if %IS_ADMIN%==1 (
        echo   C:\Program Files\YouTube Uploader
    ) else (
        echo   %LOCALAPPDATA%\YouTube Uploader
    )
    echo.
) else (
    echo ============================================
    echo [WARNING] Cleanup Incomplete
    echo ============================================
    echo.
    echo youtubeuploader is still found in PATH:
    where youtubeuploader
    echo.
    echo You may need to:
    echo   1. Restart your computer
    echo   2. Manually remove from PATH in System Properties
    echo   3. Run this script as administrator
    echo.
)

pause
