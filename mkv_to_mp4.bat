@echo off
setlocal EnableDelayedExpansion

set "input=%~1"
set "base=%~dpn1"
set "dir=%~dp1"
set "output=%base%.mp4"

REM AMF quality settings
set "VIDEO_OPTS=-c:v h264_amf -quality quality -rc cqp -qp_i 20 -qp_p 22 -pix_fmt yuv420p"

if "%input%"=="" (
echo Usage: mkv_to_mp4.bat "input.mkv"
pause
exit /b 1
)

echo Converting "%input%"...

REM ============================================================================
REM FAST PATH: REMUX + CONVERT TEXT SUBS TO MOV_TEXT
REM ============================================================================

ffmpeg -y -i "%input%" -map 0 -c copy -c:s mov_text "%output%" 2>"%TEMP%\ffmpeg_err.txt"

if %errorlevel%==0 goto done

REM ============================================================================
REM CHECK FOR IMAGE SUBS
REM ============================================================================

set "has_image_subs=0"

ffprobe -v error -select_streams s -show_entries stream=codec_name -of csv=p=0 "%input%" > "%TEMP%\sub_codecs.txt"

for /f "usebackq delims=" %%a in ("%TEMP%\sub_codecs.txt") do (
if /i "%%a"=="hdmv_pgs_subtitle" set "has_image_subs=1"
if /i "%%a"=="dvd_subtitle" set "has_image_subs=1"
)

del "%TEMP%\sub_codecs.txt" >nul 2>&1

echo.
echo Available subtitle sources:
echo.

REM ============================================================================
REM INTERNAL SUBS
REM ============================================================================

set "idx=0"

ffprobe -v error -select_streams s -show_entries stream=codec_name:stream_tags=language -of csv=p=0 "%input%" > "%TEMP%\sub_list.txt"

for /f "usebackq delims=" %%a in ("%TEMP%\sub_list.txt") do (
echo   !idx!: INTERNAL - %%a
set /a idx+=1
)

del "%TEMP%\sub_list.txt" >nul 2>&1

REM ============================================================================
REM EXTERNAL SUBS
REM ============================================================================

set "ext_idx=100"

for %%F in ("%dir%*.srt" "%dir%*.ass" "%dir%*.ssa") do (
if exist "%%~fF" (
echo   !ext_idx!: EXTERNAL - %%~nxF
set "ext_map[!ext_idx!]=%%~fF"
set /a ext_idx+=1
)
)

echo.
set /p "sub_choice=Select subtitle track/file (Enter to skip): "

REM ============================================================================
REM NO SUBS
REM ============================================================================

if "%sub_choice%"=="" (

```
echo.
echo No subtitles selected.

ffmpeg -y ^
    -i "%input%" ^
    -map 0:v:0 ^
    -map 0:a ^
    %VIDEO_OPTS% ^
    -c:a copy ^
    "%output%"

if %errorlevel% neq 0 goto fail
goto done
```

)

REM ============================================================================
REM EXTERNAL SUB FILE
REM ============================================================================

call set "ext_file=%%ext_map[%sub_choice%]%%"

if defined ext_file (

```
set "output=%base%_subbed.mp4"

echo.
echo Using external subtitle:
echo !ext_file!

ffmpeg -y ^
    -i "%input%" ^
    -i "!ext_file!" ^
    -map 0:v:0 ^
    -map 0:a ^
    -map 1:0 ^
    %VIDEO_OPTS% ^
    -c:a copy ^
    -c:s mov_text ^
    "%output%"

if %errorlevel% neq 0 goto fail
goto done
```

)

REM ============================================================================
REM INTERNAL IMAGE SUBS (BURN-IN)
REM ============================================================================

set "output=%base%_hardcoded.mp4"

echo.
echo Burning subtitle track %sub_choice%...

ffmpeg -y -i "%input%" -filter_complex "[0:v][0:s:%sub_choice%]overlay,format=yuv420p[v]" -map "[v]" -map 0:a %VIDEO_OPTS% -c:a copy "%output%"

if %errorlevel% neq 0 goto fail

goto done

REM ============================================================================
REM FAIL
REM ============================================================================

:fail
echo.
echo Conversion failed.

del "%TEMP%\ffmpeg_err.txt" >nul 2>&1

pause
exit /b 1

REM ============================================================================
REM DONE
REM ============================================================================

:done

del "%TEMP%\ffmpeg_err.txt" >nul 2>&1

echo.
echo Done:
echo %output%

pause
exit /b 0
