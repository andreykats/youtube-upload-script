@echo off
setlocal enabledelayedexpansion

REM ============================================
REM YouTube Uploader - Dependency Installer
REM Version: 1.0
REM ============================================
REM This script installs FFmpeg and youtubeuploader
REM for the YouTube upload automation script.
REM ============================================

REM ============================================
REM Global Variables
REM ============================================
set "SCRIPT_VERSION=1.0"
set "FFMPEG_URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "GITHUB_API=https://api.github.com/repos/porjo/youtubeuploader/releases/latest"
set "ADMIN_MODE=0"
set "WINGET_AVAILABLE=0"
set "FFMPEG_INSTALLED=0"
set "YOUTUBEUPLOADER_INSTALLED=0"
set "VERIFY_FAILED=0"

REM ============================================
REM Display Welcome Banner
REM ============================================
cls
echo.
echo ============================================
echo YouTube Uploader - Dependency Installer
echo ============================================
echo Version: %SCRIPT_VERSION%
echo.
echo This script will install:
echo   - FFmpeg (video processing)
echo   - FFprobe (included with FFmpeg)
echo   - youtubeuploader (YouTube upload tool)
echo.
echo ============================================
echo.

REM ============================================
REM Check Administrator Privileges
REM ============================================
echo [INFO] Checking administrator privileges...
net session >nul 2>&1
if %errorlevel% == 0 (
    set "ADMIN_MODE=1"
    echo [SUCCESS] Running with administrator privileges
    echo [INFO] Will install to Program Files with system PATH
) else (
    echo [WARNING] Not running as administrator
    echo [INFO] Attempting to elevate privileges...
    echo.

    REM Try to elevate
    powershell -Command "Start-Process '%~f0' -Verb RunAs" 2>nul
    if !errorlevel! == 0 (
        echo [INFO] Elevated script launched. Closing this window...
        timeout /t 2 >nul
        exit /b 0
    ) else (
        echo [WARNING] Elevation failed or was cancelled
        echo [INFO] Will install to user directory with user PATH
        set "ADMIN_MODE=0"
    )
)
echo.

REM ============================================
REM Set Installation Directories
REM ============================================
if %ADMIN_MODE%==1 (
    set "FFMPEG_DIR=%ProgramFiles%\FFmpeg"
    set "YOUTUBEUPLOADER_DIR=%ProgramFiles%\youtubeuploader"
    set "PATH_TYPE=system"
) else (
    set "FFMPEG_DIR=%LOCALAPPDATA%\FFmpeg"
    set "YOUTUBEUPLOADER_DIR=%LOCALAPPDATA%\youtubeuploader"
    set "PATH_TYPE=user"
)

REM ============================================
REM Environment Detection
REM ============================================
echo [INFO] Detecting environment...

REM Check for WinGet
where winget.exe >nul 2>&1
if %errorlevel% == 0 (
    set "WINGET_AVAILABLE=1"
    echo [SUCCESS] WinGet detected - will use package manager
) else (
    set "WINGET_AVAILABLE=0"
    echo [INFO] WinGet not found - will use manual download
)

REM Check for curl
where curl.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] curl not found. Please ensure you're running Windows 10 1803 or later.
    goto InstallError
)

REM Detect architecture
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "ARCH=windows_amd64"
    echo [INFO] Detected architecture: AMD64
) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "ARCH=windows_arm64"
    echo [INFO] Detected architecture: ARM64
) else (
    set "ARCH=windows_386"
    echo [INFO] Detected architecture: x86
)
echo.

REM ============================================
REM Check for Existing Installations
REM ============================================
echo [INFO] Checking for existing installations...

REM Check FFmpeg
where ffmpeg.exe >nul 2>&1
if %errorlevel% == 0 (
    echo [FOUND] FFmpeg is already installed
    for /f "tokens=3" %%a in ('ffmpeg -version 2^>nul ^| findstr "ffmpeg version"') do echo   Version: %%a
    set "FFMPEG_INSTALLED=1"
) else (
    echo [NOT FOUND] FFmpeg needs to be installed
    set "FFMPEG_INSTALLED=0"
)

REM Check youtubeuploader
where youtubeuploader.exe >nul 2>&1
if %errorlevel% == 0 (
    echo [FOUND] youtubeuploader is already installed
    youtubeuploader -version 2>nul
    set "YOUTUBEUPLOADER_INSTALLED=1"
) else (
    echo [NOT FOUND] youtubeuploader needs to be installed
    set "YOUTUBEUPLOADER_INSTALLED=0"
)
echo.

REM Ask user if they want to continue if tools are already installed
if %FFMPEG_INSTALLED%==1 if %YOUTUBEUPLOADER_INSTALLED%==1 (
    echo All dependencies are already installed.
    choice /C YN /M "Do you want to reinstall/update them"
    if !errorlevel!==2 (
        echo Installation cancelled by user.
        goto Cleanup
    )
)

REM ============================================
REM Install FFmpeg
REM ============================================
if %FFMPEG_INSTALLED%==0 (
    echo.
    echo ============================================
    echo Installing FFmpeg
    echo ============================================

    if %WINGET_AVAILABLE%==1 (
        echo [INFO] Attempting to install FFmpeg via WinGet...
        winget install --id Gyan.FFmpeg -e --disable-interactivity --accept-source-agreements --accept-package-agreements >nul 2>&1

        if !errorlevel! == 0 (
            echo [SUCCESS] FFmpeg installed via WinGet
            goto AddFFmpegToPath
        ) else (
            echo [WARNING] WinGet installation failed, trying manual download...
        )
    )

    REM Manual installation
    call :InstallFFmpegManual
    if !errorlevel! neq 0 goto InstallError
) else (
    echo [SKIP] FFmpeg is already installed
)

:AddFFmpegToPath
REM Add FFmpeg to PATH if needed
if exist "%FFMPEG_DIR%\bin\ffmpeg.exe" (
    call :AddToPath "%FFMPEG_DIR%\bin"
) else (
    REM WinGet might install to different location, check default path
    if exist "C:\Program Files\FFmpeg\bin\ffmpeg.exe" (
        set "FFMPEG_DIR=C:\Program Files\FFmpeg"
        call :AddToPath "!FFMPEG_DIR!\bin"
    )
)

REM ============================================
REM Install youtubeuploader
REM ============================================
if %YOUTUBEUPLOADER_INSTALLED%==0 (
    echo.
    echo ============================================
    echo Installing youtubeuploader
    echo ============================================

    call :InstallYoutubeUploader
    if !errorlevel! neq 0 goto InstallError
) else (
    echo [SKIP] youtubeuploader is already installed
)

REM ============================================
REM Verify Installations
REM ============================================
echo.
echo ============================================
echo Verifying Installations
echo ============================================

call :RefreshPath

echo Testing FFmpeg...
where ffmpeg.exe >nul 2>&1
if %errorlevel% == 0 (
    for /f "tokens=3" %%a in ('ffmpeg -version 2^>nul ^| findstr "ffmpeg version"') do echo   Version: %%a
    echo [OK] FFmpeg is working
) else (
    echo [FAIL] FFmpeg not found in PATH
    set "VERIFY_FAILED=1"
)

echo.
echo Testing FFprobe...
where ffprobe.exe >nul 2>&1
if %errorlevel% == 0 (
    for /f "tokens=3" %%a in ('ffprobe -version 2^>nul ^| findstr "ffprobe version"') do echo   Version: %%a
    echo [OK] FFprobe is working
) else (
    echo [FAIL] FFprobe not found in PATH
    set "VERIFY_FAILED=1"
)

echo.
echo Testing youtubeuploader...
where youtubeuploader.exe >nul 2>&1
if %errorlevel% == 0 (
    youtubeuploader -version 2>nul
    echo [OK] youtubeuploader is working
) else (
    echo [FAIL] youtubeuploader not found in PATH
    set "VERIFY_FAILED=1"
)

if %VERIFY_FAILED%==1 (
    echo.
    echo [WARNING] Some tools failed verification
    echo You may need to restart your terminal or computer for PATH changes to take effect
)

REM ============================================
REM Success
REM ============================================
echo.
echo ============================================
echo Installation Complete!
echo ============================================
echo.
echo All dependencies have been successfully installed.
echo.
echo ============================================
echo IMPORTANT: OAuth Configuration Required
echo ============================================
echo.
echo Before you can upload videos, you need to configure YouTube OAuth:
echo.
echo 1. Go to: https://console.cloud.google.com/
echo 2. Create a project and enable YouTube Data API v3
echo 3. Create OAuth credentials (Web application)
echo 4. Download client_secrets.json to this directory
echo 5. Run script.bat to authenticate (first time only)
echo.
echo For detailed instructions, see README.md
echo.
echo ============================================
echo Next Steps
echo ============================================
echo.
echo   1. Close this terminal and open a new one
echo   2. Configure OAuth (see above)
echo   3. Verify tools: ffmpeg -version
echo   4. Run upload script: script.bat ^<video-file^>
echo.
call :Cleanup
pause
exit /b 0

REM ============================================
REM SUBROUTINES
REM ============================================

REM ============================================
REM Install FFmpeg Manually
REM ============================================
:InstallFFmpegManual
echo [INFO] Downloading FFmpeg from gyan.dev...
set "FFMPEG_ZIP=%TEMP%\ffmpeg.zip"

REM Download FFmpeg
powershell -Command "Invoke-WebRequest -Uri '%FFMPEG_URL%' -OutFile '%FFMPEG_ZIP%'" 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to download FFmpeg
    exit /b 1
)
echo [SUCCESS] Download complete

REM Extract archive
echo [INFO] Extracting FFmpeg...
set "FFMPEG_EXTRACT=%TEMP%\ffmpeg_extract"
powershell -Command "Expand-Archive -Path '%FFMPEG_ZIP%' -DestinationPath '%FFMPEG_EXTRACT%' -Force" 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to extract FFmpeg
    exit /b 1
)

REM Find the extracted folder (it has version number in name)
for /d %%d in ("%FFMPEG_EXTRACT%\ffmpeg-*") do set "FFMPEG_EXTRACTED=%%d"

REM Create installation directory
if not exist "%FFMPEG_DIR%" mkdir "%FFMPEG_DIR%"

REM Move bin folder to installation directory
echo [INFO] Installing to %FFMPEG_DIR%...
xcopy /E /I /Y "%FFMPEG_EXTRACTED%\bin" "%FFMPEG_DIR%\bin" >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to copy FFmpeg files
    exit /b 1
)

echo [SUCCESS] FFmpeg installed to %FFMPEG_DIR%
exit /b 0

REM ============================================
REM Install youtubeuploader
REM ============================================
:InstallYoutubeUploader
echo [INFO] Fetching latest youtubeuploader release from GitHub...
set "TEMP_JSON=%TEMP%\yt_release.json"

REM Fetch latest release info
curl -s "%GITHUB_API%" > "%TEMP_JSON%" 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to fetch release information from GitHub
    exit /b 1
)

REM Parse JSON to find download URL for Windows binary
set "YT_URL="
for /f "tokens=* usebackq" %%a in (`type "%TEMP_JSON%" ^| findstr /i "browser_download_url.*%ARCH%\.zip"`) do (
    set "DOWNLOAD_LINE=%%a"
    REM Extract URL from JSON (remove quotes and whitespace)
    set "DOWNLOAD_LINE=!DOWNLOAD_LINE:*browser_download_url=!"
    set "DOWNLOAD_LINE=!DOWNLOAD_LINE::=!"
    set "DOWNLOAD_LINE=!DOWNLOAD_LINE:"=!"
    set "DOWNLOAD_LINE=!DOWNLOAD_LINE: =!"
    set "YT_URL=https!DOWNLOAD_LINE!"
)

if "!YT_URL!"=="" (
    echo [ERROR] Could not find Windows binary in latest release
    exit /b 1
)

echo [INFO] Found download URL: !YT_URL!
echo [INFO] Downloading youtubeuploader...

set "YT_ZIP=%TEMP%\youtubeuploader.zip"
curl -L -o "%YT_ZIP%" "!YT_URL!" 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to download youtubeuploader
    exit /b 1
)
echo [SUCCESS] Download complete

REM Extract archive
echo [INFO] Extracting youtubeuploader...
set "YT_EXTRACT=%TEMP%\yt_extract"
powershell -Command "Expand-Archive -Path '%YT_ZIP%' -DestinationPath '%YT_EXTRACT%' -Force" 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to extract youtubeuploader
    exit /b 1
)

REM Create installation directory
if not exist "%YOUTUBEUPLOADER_DIR%" mkdir "%YOUTUBEUPLOADER_DIR%"

REM Copy executable to installation directory
for /r "%YT_EXTRACT%" %%f in (youtubeuploader.exe) do (
    copy /Y "%%f" "%YOUTUBEUPLOADER_DIR%\" >nul
    echo [SUCCESS] Installed to %YOUTUBEUPLOADER_DIR%
    goto AddYTToPath
)

echo [ERROR] youtubeuploader.exe not found in archive
exit /b 1

:AddYTToPath
call :AddToPath "%YOUTUBEUPLOADER_DIR%"
exit /b 0

REM ============================================
REM Add Directory to PATH
REM ============================================
:AddToPath
set "NEW_PATH=%~1"

REM Check if already in PATH
echo %PATH% | findstr /I /C:"%NEW_PATH%" >nul
if %errorlevel% == 0 (
    echo [INFO] %NEW_PATH% already in PATH
    goto :EOF
)

echo [INFO] Adding to PATH: %NEW_PATH%

if "%PATH_TYPE%"=="system" (
    if %ADMIN_MODE%==1 (
        REM Add to system PATH
        for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYSTEM_PATH=%%b"
        setx /M PATH "!SYSTEM_PATH!;%NEW_PATH%" >nul 2>&1
        if !errorlevel! == 0 (
            echo [SUCCESS] Added to system PATH
        ) else (
            echo [WARNING] Failed to add to system PATH, trying user PATH...
            goto AddUserPath
        )
    ) else (
        goto AddUserPath
    )
) else (
:AddUserPath
    REM Add to user PATH
    for /f "skip=2 tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%b"
    if not defined USER_PATH set "USER_PATH=%PATH%"
    setx PATH "!USER_PATH!;%NEW_PATH%" >nul 2>&1
    if !errorlevel! == 0 (
        echo [SUCCESS] Added to user PATH
    ) else (
        echo [ERROR] Failed to add to PATH
    )
)
goto :EOF

REM ============================================
REM Refresh PATH for Current Session
REM ============================================
:RefreshPath
echo [INFO] Refreshing PATH for verification...
REM Read system PATH
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYSTEM_PATH=%%b"
REM Read user PATH
for /f "skip=2 tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%b"
REM Combine them
set "PATH=!SYSTEM_PATH!;!USER_PATH!"
goto :EOF

REM ============================================
REM Cleanup Temporary Files
REM ============================================
:Cleanup
echo [INFO] Cleaning up temporary files...
del /q "%TEMP%\ffmpeg.zip" 2>nul
del /q "%TEMP%\youtubeuploader.zip" 2>nul
del /q "%TEMP%\yt_release.json" 2>nul
rmdir /s /q "%TEMP%\ffmpeg_extract" 2>nul
rmdir /s /q "%TEMP%\yt_extract" 2>nul
goto :EOF

REM ============================================
REM Error Handler
REM ============================================
:InstallError
echo.
echo ============================================
echo [ERROR] Installation Failed
echo ============================================
echo An error occurred during installation.
echo.
echo Troubleshooting steps:
echo   1. Check your internet connection
echo   2. Ensure you have sufficient disk space
echo   3. Try running as administrator (right-click -^> Run as administrator)
echo   4. Check Windows Event Viewer for details
echo   5. Verify firewall isn't blocking downloads
echo.
call :Cleanup
pause
exit /b 1
