@echo off
chcp 65001 >nul
echo.
echo ========================================
echo   Xiao Phim - Build Android (APK)
echo ========================================
echo.

if "%~1"=="" (
    set /p "VERSION=Nhap version (vd: 3.3.0): "
    if "!VERSION!"=="" (
        echo Version khong duoc trong!
        pause
        exit /b 1
    )
) else (
    set "VERSION=%~1"
)

echo Version: %VERSION%
echo.

REM Lay version hien tai tu pubspec.yaml
for /f "tokens=2" %%a in ('findstr "version:" pubspec.yaml') do set "OLD_VER=%%a"
echo Version hien tai: %OLD_VER%

REM Tach build number
for /f "tokens=2 delims=+" %%a in ("%OLD_VER%") do set "BUILD=%%a"
set /a NEWBUILD=%BUILD%+1
set "NEW_VER=%VERSION%+%NEWBUILD%"

REM Cap nhat pubspec.yaml
echo Cap nhat pubspec.yaml: %NEW_VER%
powershell -Command "(Get-Content pubspec.yaml -Raw) -replace 'version: [^\r\n]+', 'version: %NEW_VER%' | Set-Content pubspec.yaml -NoNewline"
echo Done
echo.

REM Build APK
echo Building APK...
call flutter build apk --release
if errorlevel 1 (
    echo Build that bai!
    pause
    exit /b 1
)

REM Copy thang vao Downloads tren server
set "DOWNLOADS=C:\xampp\htdocs\Downloads"
if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%"

REM Xoa file cu de tiet kiem dung luong
echo Xoa file cu...
del /q "%DOWNLOADS%\xiaophim-*.apk" 2>nul
echo Done

copy "build\app\outputs\flutter-apk\app-release.apk" "%DOWNLOADS%\xiaophim-%VERSION%.apk"

echo.
echo ========================================
echo   BUILD APK HOAN TAT!
echo ========================================
echo.
echo File: %DOWNLOADS%\xiaophim-%VERSION%.apk
echo.
echo Mo admin.php -> Bam "Ap dung"
echo.
pause
