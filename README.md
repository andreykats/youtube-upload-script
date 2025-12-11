# YouTube Uploader

Automated YouTube video upload script with automatic aspect ratio correction.

## Overview

This tool automatically processes and uploads gaming videos to YouTube with:
- Automatic 16:9 aspect ratio cropping for ultrawide videos
- Smart title formatting from filename metadata
- Automated upload with configurable privacy settings

## Features

- **Auto-Crop**: Detects and crops videos wider than 16:9 to correct aspect ratio
- **Smart Titles**: Extracts game name, date, and time from filename
- **Batch Processing**: Process multiple videos via script
- **Dependency Management**: Automated installation of required tools

## Prerequisites

- **Windows 10/11** (version 1803 or later for curl support)
- **Internet connection** for downloading dependencies
- **Google Account** with YouTube channel access

## Installation

### Step 1: Install Dependencies

Run the installation script as administrator (recommended):

```batch
# Right-click install.bat -> "Run as administrator"
# Or double-click (will attempt auto-elevation)
install.bat
```

This will automatically install:
- **FFmpeg** - Video processing and cropping
- **FFprobe** - Video metadata analysis
- **youtubeuploader** - YouTube upload CLI tool

The script will:
- Try to use WinGet package manager if available
- Fall back to manual download if needed
- Add tools to your system PATH automatically
- Verify installations

**After installation**: Close and reopen your terminal for PATH changes to take effect.

### Step 2: Configure YouTube OAuth

**IMPORTANT**: youtubeuploader requires Google OAuth credentials to upload videos.

#### A. Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing)
3. Navigate to **APIs & Services → Library**
4. Search for and enable **YouTube Data API v3**

#### B. Create OAuth Credentials

1. Go to **APIs & Services → Credentials**
2. Click **CREATE CREDENTIALS → OAuth client ID**
3. If prompted, configure OAuth consent screen:
   - User Type: **External** (unless you have Google Workspace)
   - App name: Choose any name (e.g., "YouTube Uploader")
   - User support email: Your email
   - Developer contact: Your email
   - Add your Google account as a test user
4. Return to **Credentials → CREATE CREDENTIALS → OAuth client ID**
5. Application type: **Web application**
6. Name: Any name (e.g., "YouTube Uploader Client")
7. Authorized redirect URIs: Add `http://localhost:8080/oauth2callback`
8. Click **Create**
9. Click the **Download** icon (⬇️) next to your newly created OAuth client ID
10. Save the downloaded JSON file

#### C. Set Up Credentials File

1. Rename the downloaded file to `client_secrets.json`
2. Place it in this directory:
   ```
   youtube-uploader/
   └── client_secrets.json
   ```

#### D. First-Time Authentication

The first time you run the upload script:

1. youtubeuploader will automatically open your browser
2. Sign in with your Google/YouTube account
3. Grant the requested permissions
4. The browser will redirect to a success page
5. A `request.token` file will be created automatically

**Note**: Port 8080 must be available during authentication.

After this one-time setup, future uploads will use the saved token automatically.

## Usage

### Running the Upload Script

```batch
script.bat "path\to\video.mp4"
```

### Filename Format

The script expects filenames in this format:

```
GameName-YYYY.MM.DD - HH.MM.SS.MS.DVR.mp4
```

**Example**:
```
Elden Ring-2024.03.15 - 14.30.45.00.DVR.mp4
```

Will be uploaded with title:
```
Elden Ring - 2:30PM - 03.15.2024
```

### What the Script Does

1. **Checks dependencies** - Verifies FFmpeg, FFprobe, and youtubeuploader are installed
2. **Extracts metadata** - Parses game name, date, and time from filename
3. **Analyzes video** - Checks aspect ratio using FFprobe
4. **Auto-crops** (if needed) - Crops ultrawide videos to 16:9
5. **Uploads to YouTube** - Uploads with formatted title as unlisted video
6. **Cleans up** - Removes temporary cropped file

### Privacy Settings

By default, videos are uploaded as **unlisted**. To change this, edit [script.bat:152](script.bat#L152):

```batch
%UPLOADER% -filename "!UPLOAD_FILE!" -title "!VIDEO_TITLE!" -privacy unlisted
```

Options: `public`, `private`, `unlisted`

## File Structure

```
youtube-uploader/
├── install.bat           # Dependency installer
├── script.bat            # Main upload script
├── client_secrets.json   # OAuth credentials (YOU CREATE THIS)
├── request.token         # OAuth token (AUTO-GENERATED)
├── README.md             # This file
└── .gitignore            # Prevents committing secrets
```

## Troubleshooting

### Dependencies Not Found

**Error**: `[ERROR] ffmpeg.exe not found in PATH`

**Solution**:
1. Run `install.bat` as administrator
2. Restart your terminal after installation
3. Verify with: `ffmpeg -version`

### OAuth/Upload Errors

**Error**: `oauth2: cannot fetch token` or `invalid_grant`

**Solutions**:
1. Delete `request.token` and re-authenticate
2. Verify `client_secrets.json` is in the correct directory
3. Ensure your Google Cloud project has YouTube Data API v3 enabled
4. Check that your Google account is added as a test user (if using External consent screen)
5. Make sure you're using the latest version of youtubeuploader

**Error**: `Videos default to private status`

**Note**: Google applies 'private' status to videos uploaded via newly created projects by default. Request quota increase or use an established project.

### Upload Fails

**Error**: `ERROR: YouTube upload failed`

**Common causes**:
- No internet connection
- OAuth token expired (delete `request.token` and re-authenticate)
- Video file is corrupted or invalid format
- YouTube API quota exceeded
- Port 8080 is blocked by firewall

### FFmpeg Cropping Issues

**Error**: `ERROR: FFmpeg crop failed`

**Solutions**:
- Verify video file is not corrupted
- Check disk space in `%TEMP%` directory
- Ensure video codec is supported by FFmpeg

### Install Script Issues

**Error**: `[ERROR] curl not found`

**Solution**: Update to Windows 10 version 1803 or later (curl is built-in)

**Error**: `[ERROR] Failed to download`

**Solutions**:
- Check internet connection
- Verify firewall/antivirus isn't blocking downloads
- Try running as administrator

## Security Notes

### Protecting Your Credentials

**NEVER** commit these files to version control:
- `client_secrets.json` - Contains OAuth client secret
- `request.token` - Contains your access/refresh tokens

These files are listed in `.gitignore` to prevent accidental commits.

### What to Share vs. Keep Private

✅ **Safe to share**:
- `install.bat`
- `script.bat`
- `README.md`

❌ **NEVER share**:
- `client_secrets.json`
- `request.token`
- Any files containing API keys or tokens

## Advanced Configuration

### Custom Installation Directory

Edit [install.bat](install.bat) variables to change installation paths:
```batch
set "FFMPEG_DIR=%ProgramFiles%\FFmpeg"
set "YOUTUBEUPLOADER_DIR=%ProgramFiles%\youtubeuploader"
```

### Batch Processing Multiple Videos

Create a batch script to process multiple files:

```batch
@echo off
for %%f in (*.mp4) do (
    echo Processing %%f...
    call script.bat "%%f"
)
```

### Changing Video Quality

Edit the FFmpeg command in [script.bat:129](script.bat#L129) to add quality parameters:

```batch
%FFMPEG% -i "!INPUT_FILE!" -vf "crop=..." -c:a copy -c:v libx264 -crf 18 "!OUTPUT_FILE!" -y
```

Lower CRF = higher quality (range: 0-51, recommend 18-23)

## Links & Resources

- [youtubeuploader GitHub](https://github.com/porjo/youtubeuploader) - Upload tool documentation
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html) - Video processing reference
- [YouTube Data API](https://developers.google.com/youtube/v3) - API documentation
- [Google Cloud Console](https://console.cloud.google.com/) - Manage OAuth credentials

## License

This project uses the following open-source tools:
- [FFmpeg](https://ffmpeg.org/) - GPL/LGPL
- [youtubeuploader](https://github.com/porjo/youtubeuploader) - Apache 2.0

## Support

For issues with:
- **This script**: Check troubleshooting section above
- **youtubeuploader**: [Open an issue](https://github.com/porjo/youtubeuploader/issues)
- **FFmpeg**: [FFmpeg documentation](https://ffmpeg.org/ffmpeg.html)
- **YouTube API**: [Google support](https://support.google.com/youtube)
