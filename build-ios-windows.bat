@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo.
echo ========================================
echo   Xiao Phim - Build iOS trên Windows
echo   (Tự động qua GitHub Actions)
echo ========================================
echo.

REM Kiểm tra git
git --version > nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git chưa được cài đặt!
    echo Vui lòng cài Git tại: https://git-scm.com/download/win
    pause
    exit /b 1
)

REM Kiểm tra gh CLI
gh --version > nul 2>&1
if errorlevel 1 (
    echo [ERROR] GitHub CLI chưa được cài đặt!
    echo.
    echo Vui lòng cài GitHub CLI:
    echo   winget install --id GitHub.cli
    echo.
    echo Hoặc tải tại: https://cli.github.com/
    pause
    exit /b 1
)

REM Kiểm tra đã login GitHub chưa
gh auth status > nul 2>&1
if errorlevel 1 (
    echo [WARN] Chưa đăng nhập GitHub CLI!
    echo.
    set /p LOGIN="Đăng nhập ngay? (y/n): "
    if /i "!LOGIN!"=="y" (
        gh auth login
    ) else (
        echo Hủy build.
        pause
        exit /b 1
    )
)

REM Nhập version
set /p VERSION="Nhập version (vd: 3.3.6): "
if "%VERSION%"=="" (
    echo [ERROR] Version không được để trống!
    pause
    exit /b 1
)

echo.
echo Version: %VERSION%
echo.

REM Kiểm tra có remote chưa
git remote get-url origin > nul 2>&1
if errorlevel 1 (
    echo [WARN] Chưa có git remote!
    echo.
    set /p REPO_URL="Nhập GitHub repository URL (https://github.com/user/repo.git): "
    if "!REPO_URL!"=="" (
        echo [ERROR] Repository URL không được để trống!
        pause
        exit /b 1
    )
    git remote add origin !REPO_URL!
    echo Remote đã được thêm: !REPO_URL!
    echo.
)

REM Commit và push code
echo [1/5] Đang commit code...
git add .
git commit -m "Build iOS v%VERSION%" > nul 2>&1
if errorlevel 1 (
    echo Không có thay đổi để commit, tiếp tục...
)

echo [2/5] Đang push code lên GitHub...
git push origin main 2>&1 | findstr /v "warning"
if errorlevel 1 (
    echo [WARN] Push failed, thử push với -u...
    git push -u origin main
    if errorlevel 1 (
        echo [ERROR] Push thất bại!
        pause
        exit /b 1
    )
)

echo [3/5] Đang trigger GitHub Actions build...
gh workflow run build-ios.yml -f version=%VERSION%
if errorlevel 1 (
    echo [ERROR] Trigger workflow thất bại!
    echo Vui lòng kiểm tra:
    echo   - File .github/workflows/build-ios.yml đã được push chưa
    echo   - Repository có quyền chạy Actions chưa
    pause
    exit /b 1
)

echo [4/5] Chờ workflow bắt đầu...
timeout /t 5 /nobreak > nul

echo [5/5] Đang theo dõi build status...
echo.
echo ========================================
echo   Workflow đang chạy trên GitHub!
echo ========================================
echo.
echo Xem tiến trình tại:
gh run list --workflow=build-ios.yml --limit=1 --json url --jq ".[0].url"
echo.
echo Để theo dõi live:
echo   gh run watch
echo.
echo Hoặc truy cập GitHub Actions trên browser.
echo.

REM Hỏi có muốn theo dõi live không
set /p WATCH="Theo dõi build live? (y/n): "
if /i "%WATCH%"=="y" (
    echo.
    gh run watch

    REM Sau khi build xong, hỏi có download không
    echo.
    set /p DOWNLOAD="Download IPA về máy? (y/n): "
    if /i "!DOWNLOAD!"=="y" (
        echo.
        echo Đang download IPA...
        mkdir build\output 2>nul

        REM Lấy run ID mới nhất
        for /f %%i in ('gh run list --workflow=build-ios.yml --limit=1 --json databaseId --jq ".[0].databaseId"') do set RUN_ID=%%i

        REM Download artifact
        gh run download !RUN_ID! -n xiaophim-%VERSION%-ios -D build\output

        if exist "build\output\xiaophim-%VERSION%-unsigned.ipa" (
            echo.
            echo ========================================
            echo   DOWNLOAD THÀNH CÔNG!
            echo ========================================
            echo.
            echo File: build\output\xiaophim-%VERSION%-unsigned.ipa
            echo.
            echo Lưu ý: Đây là file UNSIGNED IPA
            echo Cần ký lại bằng provisioning profile để cài trên thiết bị
            echo.
        ) else (
            echo [ERROR] Không tìm thấy file IPA!
        )
    )
)

echo.
echo ========================================
echo   HOÀN TẤT!
echo ========================================
echo.
pause
