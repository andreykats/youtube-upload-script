@echo off
setlocal enabledelayedexpansion

REM ============================================
REM YouTube Upload Script with Auto-Crop
REM ============================================

set "INPUT_FILE=%~1"
set "TEMP_DIR=%TEMP%\youtube_upload"
set "FFMPEG=ffmpeg"
set "FFPROBE=ffprobe"
set "UPLOADER=youtubeuploader"
set "WHERE_CMD=%SystemRoot%\System32\where.exe"
if not exist "%WHERE_CMD%" set "WHERE_CMD=where"
set "PATH_REFRESHED=0"

REM Refresh PATH from registry to avoid stale Explorer environment
call :RefreshPath

REM Create temp directory
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM ============================================
REM Check for Required Dependencies
REM ============================================
set "MISSING_DEPS=0"

call :CheckDependency "FFmpeg" "%FFMPEG%" "ffmpeg.exe"
call :CheckDependency "FFprobe" "%FFPROBE%" "ffprobe.exe"
call :CheckDependency "youtubeuploader" "%UPLOADER%" "youtubeuploader.exe"

if !MISSING_DEPS!==1 (
    echo.
    echo ============================================
    echo [ERROR] Missing Required Dependencies
    echo ============================================
    echo.
    echo This script requires the following tools to be installed:
    echo   - FFmpeg (video processing)
    echo   - FFprobe (video analysis)
    echo   - youtubeuploader (YouTube upload tool)
    echo.
    echo Please run install.bat to install all dependencies:
    echo   ^> install.bat
    echo.
    echo Or install them manually and ensure they are in your PATH.
    echo ============================================
    echo.
    pause
    exit /b 1
)

echo [OK] All dependencies found
echo.

REM ============================================
REM Validate Input File
REM ============================================
if "!INPUT_FILE!"=="" (
    echo.
    echo ============================================
    echo [ERROR] No Input File Specified
    echo ============================================
    echo.
    echo Usage: script.bat ^<video-file^>
    echo.
    echo Example:
    echo   script.bat "GameName-2024.03.15 - 14.30.45.00.DVR.mp4"
    echo.
    echo You can also drag and drop a video file onto this script.
    echo ============================================
    echo.
    pause
    exit /b 1
)

if not exist "!INPUT_FILE!" (
    echo.
    echo ============================================
    echo [ERROR] File Not Found
    echo ============================================
    echo.
    echo The specified file does not exist:
    echo   !INPUT_FILE!
    echo.
    echo Please check the file path and try again.
    echo ============================================
    echo.
    pause
    exit /b 1
)

REM ============================================
REM Extract metadata from filename
REM ============================================
set "FILENAME=%~n1"

REM Remove " - Trim" suffix if present
set "FILENAME=!FILENAME: - Trim=!"

REM Split by date pattern (YYYY.MM.DD)
for /f "tokens=1,2 delims=-" %%a in ("!FILENAME!") do (
    set "GAME_NAME=%%a"
    set "DATETIME=%%b"
)

REM Trim spaces
set "GAME_NAME=!GAME_NAME: =!"
for /f "tokens=* delims= " %%a in ("!GAME_NAME!") do set "GAME_NAME=%%a"

REM Extract date and time from DATETIME (format: "YYYY.MM.DD - HH.MM.SS.MS.DVR")
for /f "tokens=1,2,3 delims=." %%a in ("!DATETIME!") do (
    set "YEAR=%%a"
    set "MONTH=%%b"
    set "DAY=%%c"
)

REM Extract time (HH.MM.SS)
for /f "tokens=4,5,6 delims=." %%a in ("!DATETIME!") do (
    set "HOUR=%%a"
    set "MINUTE=%%b"
    set "SECOND=%%c"
)

REM Trim leading spaces
set "HOUR=!HOUR: =!"
set "MINUTE=!MINUTE: =!"
set "DAY=!DAY: =!"

REM Validate time components
if "!HOUR!"=="" set "HOUR=00"
if "!MINUTE!"=="" set "MINUTE=00"

REM Convert to 12-hour format with AM/PM
set /a "HOUR_NUM=1!HOUR! %% 100"
if !HOUR_NUM! geq 12 (
    set "AMPM=PM"
    if !HOUR_NUM! gtr 12 (
        set /a "HOUR_12=!HOUR_NUM! - 12"
    ) else (
        set "HOUR_12=12"
    )
) else (
    set "AMPM=AM"
    if !HOUR_NUM!==0 (
        set "HOUR_12=12"
    ) else (
        set "HOUR_12=!HOUR_NUM!"
    )
)

REM Remove leading zero from minute if present
set /a "MINUTE_NUM=1!MINUTE! %% 100"

REM Format title: "Game Name - H:MMAM/PM - MM.DD.YYYY"
set "VIDEO_TITLE=!GAME_NAME! - !HOUR_12!:!MINUTE!!AMPM! - !MONTH!.!DAY!.!YEAR!"

echo.
echo ============================================
echo YouTube Upload Script
echo ============================================
echo Input File: !INPUT_FILE!
echo Video Title: !VIDEO_TITLE!
echo ============================================
echo.

REM ============================================
REM Check video aspect ratio
REM ============================================
echo Checking video aspect ratio...

for /f "tokens=*" %%a in ('%FFPROBE% -v error -select_streams v:0 -show_entries stream^=width^,height -of csv^=s^=x:p^=0 "!INPUT_FILE!"') do set "DIMENSIONS=%%a"

if "!DIMENSIONS!"=="" (
    echo ERROR: Failed to read video dimensions
    echo Make sure the file is a valid video file
    pause
    exit /b 1
)

for /f "tokens=1,2 delims=x" %%a in ("!DIMENSIONS!") do (
    set "WIDTH=%%a"
    set "HEIGHT=%%b"
)

if "!HEIGHT!"=="" set "HEIGHT=0"
if "!WIDTH!"=="" set "WIDTH=0"

if !HEIGHT! equ 0 (
    echo ERROR: Invalid video dimensions - height is zero
    pause
    exit /b 1
)

REM Calculate aspect ratio (width/height * 100 for integer math)
set /a "ASPECT_RATIO=(!WIDTH! * 100) / !HEIGHT!"
set /a "TARGET_RATIO=177"

echo Video dimensions: !WIDTH!x!HEIGHT!
echo Aspect ratio: !ASPECT_RATIO! (16:9 = 177)

if !ASPECT_RATIO! gtr !TARGET_RATIO! (
    echo Video is wider than 16:9 - cropping required
    set "NEEDS_CROP=1"
) else (
    echo Video is 16:9 or narrower - no crop needed
    set "NEEDS_CROP=0"
)

REM ============================================
REM Crop video if needed
REM ============================================
if "!NEEDS_CROP!"=="1" (
    echo.
    echo Cropping video to 16:9...
    
    REM Calculate 16:9 crop dimensions
    set /a "NEW_WIDTH=(!HEIGHT! * 16) / 9"
    set /a "X_OFFSET=(!WIDTH! - !NEW_WIDTH!) / 2"
    
    set "OUTPUT_FILE=%TEMP_DIR%\cropped_video.mp4"
    
    echo Crop dimensions: !NEW_WIDTH!x!HEIGHT! starting at X=!X_OFFSET!
    
    %FFMPEG% -i "!INPUT_FILE!" -vf "crop=!NEW_WIDTH!:!HEIGHT!:!X_OFFSET!:0" -c:a copy "!OUTPUT_FILE!" -y
    set "FFMPEG_CROP_ERR=!errorlevel!"

    if !FFMPEG_CROP_ERR! neq 0 (
        echo ERROR: FFmpeg crop failed
        pause
        exit /b 1
    )
    
    echo Crop complete!
    set "UPLOAD_FILE=!OUTPUT_FILE!"
) else (
    set "UPLOAD_FILE=!INPUT_FILE!"
)

REM ============================================
REM Upload to YouTube
REM ============================================
echo.
echo Uploading to YouTube...
echo Title: !VIDEO_TITLE!
echo File: !UPLOAD_FILE!
echo.

%UPLOADER% -filename "!UPLOAD_FILE!" -title "!VIDEO_TITLE!" -privacy unlisted
set "UPLOAD_ERR=!errorlevel!"

if !UPLOAD_ERR! neq 0 (
    echo ERROR: YouTube upload failed
    pause
    exit /b 1
)

REM ============================================
REM Cleanup
REM ============================================
if "!NEEDS_CROP!"=="1" (
    echo Cleaning up temporary files...
    del "!OUTPUT_FILE!" 2>nul
)

echo.
echo ============================================
echo Upload complete!
echo ============================================
echo.
pause
goto :EOF

REM ============================================
REM SUBROUTINES
REM ============================================
:RefreshPath
REM Combine system + user PATH from registry to catch recent installs when double-clicked from Explorer
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYSTEM_PATH=%%b"
for /f "skip=2 tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%b"
if defined SYSTEM_PATH if defined USER_PATH (
    set "PATH=!SYSTEM_PATH!;!USER_PATH!"
    set "PATH_REFRESHED=1"
)
goto :EOF

:CheckDependency
REM Arguments:
REM   %1 - Friendly name (FFmpeg, FFprobe, etc.)
REM   %2 - Command or path to check
REM   %3 - Fallback executable name (with .exe)

set "DEP_NAME=%~1"
set "DEP_CMD=%~2"
set "DEP_FALLBACK=%~3"
set "DEP_FOUND="
set "DEP_CMD_RAW=%DEP_CMD:"=%"
set "DEP_FALLBACK_RAW=%DEP_FALLBACK:"=%"

REM Direct path check first (covers custom absolute paths)
if defined DEP_CMD_RAW if exist "%DEP_CMD_RAW%" set "DEP_FOUND=%DEP_CMD_RAW%"
if not defined DEP_FOUND if defined DEP_FALLBACK_RAW if exist "%DEP_FALLBACK_RAW%" set "DEP_FOUND=%DEP_FALLBACK_RAW%"

REM PATH lookup using %%~$PATH (respects PATHEXT)
for %%i in ("%DEP_CMD_RAW%") do if not defined DEP_FOUND set "DEP_FOUND=%%~$PATH:i"
for %%i in ("%DEP_FALLBACK_RAW%") do if not defined DEP_FOUND set "DEP_FOUND=%%~$PATH:i"

REM where.exe lookup as extra safety (handles wildcards)
if not defined DEP_FOUND (
    "%WHERE_CMD%" /q "%DEP_CMD_RAW%" >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "delims=" %%p in ('"%WHERE_CMD%" "%DEP_CMD_RAW%" 2^>nul') do (
            set "DEP_FOUND=%%p"
            goto :CheckDepFound
        )
    )
)

if not defined DEP_FOUND (
    "%WHERE_CMD%" /q "%DEP_FALLBACK_RAW%" >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "delims=" %%p in ('"%WHERE_CMD%" "%DEP_FALLBACK_RAW%" 2^>nul') do (
            set "DEP_FOUND=%%p"
            goto :CheckDepFound
        )
    )
)

REM Check well-known install locations (installer defaults)
if not defined DEP_FOUND (
    call :FindDefaultInstall "%DEP_NAME%" DEP_FOUND
)

if not defined DEP_FOUND (
    echo [ERROR] %DEP_NAME% not found in PATH (looked for "%DEP_CMD%" and "%DEP_FALLBACK%")
    echo [INFO] Current PATH is:
    echo !PATH!
    if !PATH_REFRESHED! equ 0 (
        echo [INFO] PATH may be stale. Re-reading PATH from registry and retrying...
        call :RefreshPath
        set "PATH_REFRESHED=1"
        goto :CheckDependency
    )
    set "MISSING_DEPS=1"
    goto :EOF
)

:CheckDepFound
echo [OK] %DEP_NAME% found at: !DEP_FOUND!
goto :EOF

:FindDefaultInstall
REM Finds tool in default installer locations
REM   %1 - Friendly name
REM   %2 - Output variable
set "FD_NAME=%~1"
set "FD_OUT_VAR=%~2"
set "FD_FOUND="

if /i "%FD_NAME%"=="FFmpeg" (
    if exist "%ProgramFiles%\FFmpeg\bin\ffmpeg.exe" set "FD_FOUND=%ProgramFiles%\FFmpeg\bin\ffmpeg.exe"
    if not defined FD_FOUND if exist "%LOCALAPPDATA%\FFmpeg\bin\ffmpeg.exe" set "FD_FOUND=%LOCALAPPDATA%\FFmpeg\bin\ffmpeg.exe"
)

if /i "%FD_NAME%"=="FFprobe" (
    if exist "%ProgramFiles%\FFmpeg\bin\ffprobe.exe" set "FD_FOUND=%ProgramFiles%\FFmpeg\bin\ffprobe.exe"
    if not defined FD_FOUND if exist "%LOCALAPPDATA%\FFmpeg\bin\ffprobe.exe" set "FD_FOUND=%LOCALAPPDATA%\FFmpeg\bin\ffprobe.exe"
)

if /i "%FD_NAME%"=="youtubeuploader" (
    if exist "%ProgramFiles%\YouTube Uploader\youtubeuploader.exe" set "FD_FOUND=%ProgramFiles%\YouTube Uploader\youtubeuploader.exe"
    if not defined FD_FOUND if exist "%LOCALAPPDATA%\YouTube Uploader\youtubeuploader.exe" set "FD_FOUND=%LOCALAPPDATA%\YouTube Uploader\youtubeuploader.exe"
    if not defined FD_FOUND if exist "C:\Program Files\youtubeuploader\youtubeuploader.exe" set "FD_FOUND=C:\Program Files\youtubeuploader\youtubeuploader.exe"
    if not defined FD_FOUND if exist "%LOCALAPPDATA%\youtubeuploader\youtubeuploader.exe" set "FD_FOUND=%LOCALAPPDATA%\youtubeuploader\youtubeuploader.exe"
)

if defined FD_FOUND set "%FD_OUT_VAR%=%FD_FOUND%"
goto :EOF
