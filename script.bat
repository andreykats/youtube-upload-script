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

REM Create temp directory
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM ============================================
REM Check for Required Dependencies
REM ============================================
set "MISSING_DEPS=0"

where ffmpeg.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ffmpeg.exe not found in PATH
    set "MISSING_DEPS=1"
)

where ffprobe.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ffprobe.exe not found in PATH
    set "MISSING_DEPS=1"
)

where youtubeuploader.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] youtubeuploader.exe not found in PATH
    set "MISSING_DEPS=1"
)

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

for /f "tokens=1,2 delims=x" %%a in ("!DIMENSIONS!") do (
    set "WIDTH=%%a"
    set "HEIGHT=%%b"
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
    
    if !ERRORLEVEL! neq 0 (
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

if !ERRORLEVEL! neq 0 (
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