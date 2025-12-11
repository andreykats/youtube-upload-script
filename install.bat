@echo off
setlocal enabledelayedexpansion

REM ============================================
REM YouTube Upload Script - Dependency Installer
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
set "YOUTUBEUPLOADER_URL=https://github.com/porjo/youtubeuploader/releases/download/v1.25.5/youtubeuploader_1.25.5_Windows_amd64.zip"
set "ADMIN_MODE=0"
set "WINGET_AVAILABLE=0"
set "FFMPEG_INSTALLED=0"
set "YOUTUBEUPLOADER_INSTALLED=0"
set "VERIFY_FAILED=0"
set "DEBUG_MODE=0"
set "DOWNLOAD_ERROR_MSG="
set "DOWNLOAD_MAX_RETRIES=3"
set "DOWNLOAD_TIMEOUT=120"
set "DOWNLOAD_CONNECT_TIMEOUT=30"

REM ============================================
REM Display Welcome Banner
REM ============================================
cls
echo.
echo ============================================
echo YouTube Upload Script - Dependency Installer
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

REM Check for debug mode from environment variable
if /i "%INSTALL_DEBUG%"=="1" set "DEBUG_MODE=1"
if /i "%INSTALL_DEBUG%"=="true" set "DEBUG_MODE=1"

REM ============================================
REM Check Administrator Privileges
REM ============================================
echo [INFO] Checking administrator privileges...
net session >nul 2>&1
set "ADMIN_CHECK=!errorlevel!"
if !ADMIN_CHECK! == 0 (
    set "ADMIN_MODE=1"
    echo [SUCCESS] Running with administrator privileges
    echo [INFO] Will install to Program Files with system PATH
) else (
    echo [WARNING] Not running as administrator
    echo [INFO] Attempting to elevate privileges...
    echo.

    REM Try to elevate
    powershell -Command "Start-Process '%~f0' -Verb RunAs" 2>nul
    set "ELEVATE_CHECK=!errorlevel!"
    if !ELEVATE_CHECK! == 0 (
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
    set "YOUTUBEUPLOADER_DIR=%ProgramFiles%\YouTube Uploader"
    set "PATH_TYPE=system"
) else (
    set "FFMPEG_DIR=%LOCALAPPDATA%\FFmpeg"
    set "YOUTUBEUPLOADER_DIR=%LOCALAPPDATA%\YouTube Uploader"
    set "PATH_TYPE=user"
)

REM ============================================
REM Environment Detection
REM ============================================
echo [INFO] Detecting environment...

REM Check for WinGet
where winget.exe >nul 2>&1
set "WINGET_CHECK=!errorlevel!"
if !WINGET_CHECK! == 0 (
    set "WINGET_AVAILABLE=1"
    echo [SUCCESS] WinGet detected - will use package manager
) else (
    set "WINGET_AVAILABLE=0"
    echo [INFO] WinGet not found - will use manual download
)

REM Check for curl
where curl.exe >nul 2>&1
set "CURL_CHECK=!errorlevel!"
if !CURL_CHECK! neq 0 (
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
set "FFMPEG_CHECK_ERR=!errorlevel!"
if !FFMPEG_CHECK_ERR! == 0 (
    echo [FOUND] FFmpeg is already installed
    for /f "tokens=3" %%a in ('ffmpeg -version 2^>nul ^| findstr "ffmpeg version"') do echo   Version: %%a
    set "FFMPEG_INSTALLED=1"
) else (
    echo [NOT FOUND] FFmpeg needs to be installed
    set "FFMPEG_INSTALLED=0"
)

REM Check youtubeuploader
where youtubeuploader.exe >nul 2>&1
set "YT_CHECK_ERR=!errorlevel!"
if !YT_CHECK_ERR! == 0 (
    echo [FOUND] youtubeuploader is already installed
    youtubeuploader -version 2>nul
    set "YOUTUBEUPLOADER_INSTALLED=1"
) else (
    echo [NOT FOUND] youtubeuploader needs to be installed
    set "YOUTUBEUPLOADER_INSTALLED=0"
)
echo.

REM Ask user if they want to continue if tools are already installed
if !FFMPEG_INSTALLED!==1 if !YOUTUBEUPLOADER_INSTALLED!==1 (
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
set "FFMPEG_VER_CHECK=!errorlevel!"
if !FFMPEG_VER_CHECK! == 0 (
    for /f "tokens=3" %%a in ('ffmpeg -version 2^>nul ^| findstr "ffmpeg version"') do echo   Version: %%a
    echo [OK] FFmpeg is working
) else (
    echo [FAIL] FFmpeg not found in PATH
    set "VERIFY_FAILED=1"
)

echo.
echo Testing FFprobe...
where ffprobe.exe >nul 2>&1
set "FFPROBE_VER_CHECK=!errorlevel!"
if !FFPROBE_VER_CHECK! == 0 (
    for /f "tokens=3" %%a in ('ffprobe -version 2^>nul ^| findstr "ffprobe version"') do echo   Version: %%a
    echo [OK] FFprobe is working
) else (
    echo [FAIL] FFprobe not found in PATH
    set "VERIFY_FAILED=1"
)

echo.
echo Testing youtubeuploader...
where youtubeuploader.exe >nul 2>&1
set "UPLOADER_VER_CHECK=!errorlevel!"
if !UPLOADER_VER_CHECK! == 0 (
    youtubeuploader -version 2>nul
    echo [OK] youtubeuploader is working
) else (
    echo [FAIL] youtubeuploader not found in PATH
    set "VERIFY_FAILED=1"
)

if !VERIFY_FAILED!==1 (
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
call :DebugLog "Starting FFmpeg download from %FFMPEG_URL%"
call :DownloadFileRobust "%FFMPEG_URL%" "%FFMPEG_ZIP%" "FFmpeg"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to download FFmpeg after %DOWNLOAD_MAX_RETRIES% attempts
    echo [ERROR] Reason: !DOWNLOAD_ERROR_MSG!
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
echo [INFO] Downloading youtubeuploader from GitHub...

REM Use direct download URL for youtubeuploader
set "YT_URL=%YOUTUBEUPLOADER_URL%"
call :DebugLog "Using download URL: !YT_URL!"
echo [INFO] Downloading youtubeuploader v1.25.5...

set "YT_ZIP=%TEMP%\youtubeuploader.zip"
call :DebugLog "Download URL: !YT_URL!"
call :DebugLog "Output path: %YT_ZIP%"

call :DownloadFileRobust "!YT_URL!" "%YT_ZIP%" "youtubeuploader"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to download youtubeuploader after %DOWNLOAD_MAX_RETRIES% attempts
    echo [ERROR] Reason: !DOWNLOAD_ERROR_MSG!
    echo [HINT] Try running with DEBUG mode: set INSTALL_DEBUG=1
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
rmdir /s /q "%TEMP%\ffmpeg_extract" 2>nul
rmdir /s /q "%TEMP%\yt_extract" 2>nul
goto :EOF

REM ============================================
REM Debug Logging
REM ============================================
:DebugLog
REM Logs debug messages when DEBUG_MODE is enabled
REM Arguments:
REM   %1 - Message to log

if "%DEBUG_MODE%"=="0" goto :EOF

setlocal enabledelayedexpansion
set "MSG=%~1"

REM Get timestamp
for /f "tokens=1-4 delims=:.," %%a in ("%time%") do (
    set "TIMESTAMP=%%a:%%b:%%c.%%d"
)

echo [DEBUG %TIMESTAMP%] !MSG!
echo [DEBUG %TIMESTAMP%] !MSG! >> "%TEMP%\install_debug.log" 2>nul

endlocal
goto :EOF

REM ============================================
REM Map Curl Error Codes
REM ============================================
:GetCurlErrorMessage
REM Maps curl exit codes to human-readable error messages
REM Arguments:
REM   %1 - Curl exit code
REM   %2 - Output variable name
REM Returns: Always 0, sets output variable

setlocal
set "EXIT_CODE=%~1"
set "MSG="

if "%EXIT_CODE%"=="1" set "MSG=Unsupported protocol"
if "%EXIT_CODE%"=="3" set "MSG=Malformed URL"
if "%EXIT_CODE%"=="5" set "MSG=Couldn't resolve proxy"
if "%EXIT_CODE%"=="6" set "MSG=Couldn't resolve host - check DNS and internet connection"
if "%EXIT_CODE%"=="7" set "MSG=Failed to connect to server - check firewall and network"
if "%EXIT_CODE%"=="22" set "MSG=HTTP error (404 Not Found, 403 Forbidden, etc.)"
if "%EXIT_CODE%"=="23" set "MSG=Write error - check disk space and permissions"
if "%EXIT_CODE%"=="28" set "MSG=Operation timeout - slow connection or server not responding"
if "%EXIT_CODE%"=="35" set "MSG=SSL/TLS connection error - certificate validation failed"
if "%EXIT_CODE%"=="47" set "MSG=Too many redirects"
if "%EXIT_CODE%"=="52" set "MSG=Server returned nothing"
if "%EXIT_CODE%"=="56" set "MSG=Connection reset by peer - network interruption"
if "%EXIT_CODE%"=="60" set "MSG=SSL certificate problem - invalid or expired certificate"
if "%EXIT_CODE%"=="90" set "MSG=Downloaded file validation failed - file is empty or corrupted"

if "!MSG!"=="" set "MSG=Unknown error (exit code %EXIT_CODE%)"

endlocal & set "%~2=%MSG%" & exit /b 0

REM ============================================
REM Validate Downloaded File
REM ============================================
:ValidateDownloadedFile
REM Validates a downloaded file exists and has content
REM Arguments:
REM   %1 - File path to validate
REM Returns:
REM   0 - Valid file
REM   1 - Invalid file

setlocal
set "FILE_PATH=%~1"

call :DebugLog "Validating file: %FILE_PATH%"

REM Check file exists
if not exist "%FILE_PATH%" (
    call :DebugLog "File does not exist"
    endlocal & exit /b 1
)

REM Check file size > 0
for %%F in ("%FILE_PATH%") do set "FILE_SIZE=%%~zF"
call :DebugLog "File size: %FILE_SIZE% bytes"

if %FILE_SIZE% equ 0 (
    call :DebugLog "File is empty (0 bytes)"
    endlocal & exit /b 1
)

call :DebugLog "File validation passed"
endlocal & exit /b 0

REM ============================================
REM Robust Download Function
REM ============================================
:DownloadFileRobust
REM Downloads a file with retry logic and comprehensive error handling
REM Arguments:
REM   %1 - URL to download
REM   %2 - Output file path
REM   %3 - Description (for user messages)
REM Returns:
REM   0 - Success
REM   1 - Failed after all retries
REM   Sets DOWNLOAD_ERROR_MSG with error description

setlocal enabledelayedexpansion
set "URL=%~1"
set "OUTPUT=%~2"
set "DESC=%~3"
set "ATTEMPT=0"
set "MAX_RETRIES=%DOWNLOAD_MAX_RETRIES%"
set "SUCCESS=0"

call :DebugLog "DownloadFileRobust called: URL=%URL%, OUTPUT=%OUTPUT%, DESC=%DESC%"

:RetryLoop
set /a ATTEMPT+=1
call :DebugLog "Download attempt %ATTEMPT% of %MAX_RETRIES%"

REM Calculate backoff delay for retry (1s, 3s, 9s)
set /a BACKOFF_DELAY=1
if %ATTEMPT% gtr 1 (
    set /a BACKOFF_DELAY=3*(%ATTEMPT%-1)
)

if %ATTEMPT% gtr 1 (
    echo [RETRY] Attempt %ATTEMPT% of %MAX_RETRIES% after !BACKOFF_DELAY!s delay...
    timeout /t !BACKOFF_DELAY! /nobreak >nul
)

REM Perform download with full error output and timeouts
set "CURL_ERROR_FILE=%TEMP%\curl_error_%RANDOM%.txt"

curl -L --fail --max-time %DOWNLOAD_TIMEOUT% --connect-timeout %DOWNLOAD_CONNECT_TIMEOUT% --show-error -o "%OUTPUT%" "%URL%" 2>"%CURL_ERROR_FILE%"

set "CURL_EXIT=%errorlevel%"
call :DebugLog "Curl exit code: %CURL_EXIT%"

if %CURL_EXIT% equ 0 (
    REM Download succeeded, validate file
    call :DebugLog "Download completed, validating file..."

    call :ValidateDownloadedFile "%OUTPUT%"
    if !errorlevel! equ 0 (
        set "SUCCESS=1"
        call :DebugLog "File validation successful"
        del "%CURL_ERROR_FILE%" 2>nul
        goto DownloadSuccess
    ) else (
        call :DebugLog "File validation failed"
        set "CURL_EXIT=90"
    )
) else (
    REM Download failed, log error details
    call :DebugLog "Download failed with exit code %CURL_EXIT%"

    if exist "%CURL_ERROR_FILE%" (
        for /f "delims=" %%a in (%CURL_ERROR_FILE%) do (
            echo [CURL ERROR] %%a
            call :DebugLog "Curl stderr: %%a"
        )
        del "%CURL_ERROR_FILE%" 2>nul
    )
)

REM Check if we should retry
if %ATTEMPT% lss %MAX_RETRIES% (
    REM Determine if error is retryable
    if %CURL_EXIT% equ 22 (
        echo [ERROR] HTTP error - resource not found or forbidden
        goto DownloadFailed
    )
    if %CURL_EXIT% equ 23 (
        echo [ERROR] Cannot write to disk - check disk space and permissions
        goto DownloadFailed
    )

    REM Retryable error, continue loop
    goto RetryLoop
) else (
    goto DownloadFailed
)

:DownloadSuccess
call :DebugLog "Download successful after %ATTEMPT% attempt(s)"
endlocal & set "DOWNLOAD_ERROR_MSG=" & exit /b 0

:DownloadFailed
call :GetCurlErrorMessage %CURL_EXIT% ERROR_MSG
endlocal & set "DOWNLOAD_ERROR_MSG=%ERROR_MSG%" & exit /b 1

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
echo   6. Run with debug mode: set INSTALL_DEBUG=1 ^&^& install.bat
echo   7. Check debug log: %TEMP%\install_debug.log
echo.
call :Cleanup
pause
exit /b 1
