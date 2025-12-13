@echo off
setlocal enabledelayedexpansion

REM ============================================
REM YouTube Upload Script with Auto-Crop
REM ============================================

set "INPUT_FILE=%~1"
set "TEMP_DIR=%TEMP%\youtube_upload"
set "INPUT_BASENAME=%~n1"
set "INPUT_EXT=%~x1"
set "SCRIPT_DIR=%~dp0"
set "FFMPEG=ffmpeg.exe"
set "FFPROBE=ffprobe.exe"
set "UPLOADER=youtubeuploader.exe"
set "CROPPED_CREATED=0"
set "YT_SECRETS="

REM Create temp directory
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

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
    echo   script.bat "Game Name 2024.03.15 - 14.30.45.00.DVR.mp4"
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

REM Resolve input directory (for cropped output)
for %%I in ("!INPUT_FILE!") do set "INPUT_DIR=%%~dpI"

REM Locate YouTube client secrets
if exist "!SCRIPT_DIR!client_secrets.json" set "YT_SECRETS=!SCRIPT_DIR!client_secrets.json"
if not defined YT_SECRETS if exist "!SCRIPT_DIR!client_secret.json" set "YT_SECRETS=!SCRIPT_DIR!client_secret.json"
if not defined YT_SECRETS if exist "%APPDATA%\youtubeuploader\client_secrets.json" set "YT_SECRETS=%APPDATA%\youtubeuploader\client_secrets.json"
if not defined YT_SECRETS (
    echo.
    echo ============================================
    echo [ERROR] client_secrets.json not found
    echo ============================================
    echo Place client_secrets.json in:
    echo   - !SCRIPT_DIR!
    echo or
    echo   - %APPDATA%\youtubeuploader\
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

REM Expect format: "Game Name YYYY.MM.DD - HH.MM.SS.MS.DVR"
REM Replace " - " with "|" to split date and time
set "NAME_DATE_TIME=!FILENAME: - =|!"
for /f "tokens=1,2 delims=|" %%a in ("!NAME_DATE_TIME!") do (
    set "GAME_AND_DATE=%%a"
    set "TIME_PART=%%b"
)

REM Trim spaces from game+date segment
for /f "tokens=* delims= " %%a in ("!GAME_AND_DATE!") do set "GAME_AND_DATE=%%a"

REM Extract date (last 10 chars = YYYY.MM.DD) and game name (everything before the space)
set "DATE_STR=!GAME_AND_DATE:~-10!"
set "GAME_NAME=!GAME_AND_DATE:~0,-11!"

REM Trim spaces from game name
for /f "tokens=* delims= " %%a in ("!GAME_NAME!") do set "GAME_NAME=%%a"

REM Extract date components
for /f "tokens=1,2,3 delims=." %%a in ("!DATE_STR!") do (
    set "YEAR=%%a"
    set "MONTH=%%b"
    set "DAY=%%c"
)

REM Extract time components (HH.MM.SS from TIME_PART)
for /f "tokens=1,2,3 delims=." %%a in ("!TIME_PART!") do (
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
    set "OUTPUT_FILE=!INPUT_DIR!!INPUT_BASENAME! - Cropped!INPUT_EXT!"

    if exist "!OUTPUT_FILE!" (
        echo.
        echo Cropped file already exists, skipping crop.
        set "UPLOAD_FILE=!OUTPUT_FILE!"
    ) else (
        echo.
        echo Cropping video to 16:9...
        
        REM Calculate 16:9 crop dimensions
        set /a "NEW_WIDTH=(!HEIGHT! * 16) / 9"
        set /a "X_OFFSET=(!WIDTH! - !NEW_WIDTH!) / 2"
        
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
        set "CROPPED_CREATED=1"
    )
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

set "UPLOAD_LOG=%TEMP_DIR%\upload_output.txt"
"%UPLOADER%" -filename "!UPLOAD_FILE!" -title "!VIDEO_TITLE!" -description "" -privacy public -secrets "!YT_SECRETS!" -cache "!SCRIPT_DIR!request.token" > "!UPLOAD_LOG!" 2>&1
set "UPLOAD_ERR=!errorlevel!"

if !UPLOAD_ERR! neq 0 (
    echo ERROR: YouTube upload failed
    pause
    exit /b 1
)

REM ============================================
REM Parse Video ID and Open in Browser
REM ============================================
set "VIDEO_ID="
set "YOUTUBE_URL="

if exist "!UPLOAD_LOG!" (
    for /f "tokens=1,2,3*" %%a in ('type "!UPLOAD_LOG!" ^| findstr /C:"Video ID:"') do (
        set "VIDEO_ID=%%c"
    )

    if defined VIDEO_ID (
        set "YOUTUBE_URL=https://www.youtube.com/watch?v=!VIDEO_ID!"
        echo.
        echo ============================================
        echo Opening video in browser...
        echo URL: !YOUTUBE_URL!
        echo ============================================
        echo.
        start "" "!YOUTUBE_URL!"
    ) else (
        echo.
        echo [WARNING] Could not extract Video ID from upload output
        echo Upload succeeded but cannot open browser automatically
        echo.
    )

    REM Clean up upload log
    del "!UPLOAD_LOG!" 2>nul
)

REM ============================================
REM Cleanup
REM ============================================
if "!NEEDS_CROP!"=="1" if "!CROPPED_CREATED!"=="1" (
    echo Cleaning up temporary files...
    del "!OUTPUT_FILE!" 2>nul
)

echo.
echo ============================================
echo Upload complete!
if defined YOUTUBE_URL (
    echo Video URL: !YOUTUBE_URL!
)
echo ============================================
echo.
pause
exit /b 0
