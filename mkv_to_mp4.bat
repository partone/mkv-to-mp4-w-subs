@echo off
setlocal

REM Get the full path of the file
set "input=%~1"

REM Build the output filename with same path/name but .mp4
set "output=%~dpn1.mp4"

echo Converting "%input%" to "%output%"...
ffmpeg -i "%input%" -map 0 -c copy -c:s mov_text "%output%"

echo Done.
pause