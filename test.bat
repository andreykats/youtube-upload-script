@echo off
echo Testing where command in batch file:
where ffmpeg.exe
echo FFmpeg errorlevel: %errorlevel%
where ffprobe.exe  
echo FFprobe errorlevel: %errorlevel%
where youtubeuploader.exe
echo youtubeuploader errorlevel: %errorlevel%
pause