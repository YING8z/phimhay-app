# ============================================
# Xiao Phim - Build iOS tu Windows
# Tu dong qua GitHub Actions
# ============================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Xiao Phim - Build iOS tu Windows" -ForegroundColor Cyan
Write-Host "  (Tu dong qua GitHub Actions)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kiem tra gh CLI
try {
    gh --version | Out-Null
} catch {
    Write-Host "[ERROR] GitHub CLI chua cai dat!" -ForegroundColor Red
    Write-Host "Cai dat: winget install --id GitHub.cli"
    Read-Host "Nhan Enter de thoat"
    exit 1
}

# Kiem tra da login chua
try {
    gh auth status 2>&1 | Out-Null
} catch {
    Write-Host "[WARN] Chua dang nhap GitHub CLI!" -ForegroundColor Yellow
    $login = Read-Host "Dang nhap ngay? (y/n)"
    if ($login -eq "y") {
        gh auth login
    } else {
        Write-Host "Huy build."
        Read-Host "Nhan Enter de thoat"
        exit 1
    }
}

# Nhap version
$VERSION = Read-Host "Nhap version (vd: 3.3.6)"
if ([string]::IsNullOrWhiteSpace($VERSION)) {
    Write-Host "[ERROR] Version khong duoc trong!" -ForegroundColor Red
    Read-Host "Nhan Enter de thoat"
    exit 1
}

Write-Host ""
Write-Host "Version: $VERSION" -ForegroundColor Green
Write-Host ""

# Kiem tra remote
$remoteUrl = git remote get-url origin 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Chua co git remote!" -ForegroundColor Yellow
    $repoUrl = Read-Host "Nhap GitHub repository URL (https://github.com/user/repo.git)"
    if ([string]::IsNullOrWhiteSpace($repoUrl)) {
        Write-Host "[ERROR] Repository URL khong duoc trong!" -ForegroundColor Red
        Read-Host "Nhan Enter de thoat"
        exit 1
    }
    git remote add origin $repoUrl
    Write-Host "Remote da them: $repoUrl" -ForegroundColor Green
    Write-Host ""
}

# Commit code
Write-Host "[1/5] Dang commit code..." -ForegroundColor Cyan
git add .
git commit -m "Build iOS v$VERSION" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Khong co thay doi de commit, tiep tuc..." -ForegroundColor Yellow
}

# Push code
Write-Host "[2/5] Dang push code len GitHub..." -ForegroundColor Cyan
$branch = git branch --show-current 2>&1
git push origin $branch 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Push failed, thu push voi -u..." -ForegroundColor Yellow
    git push -u origin $branch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Push that bai!" -ForegroundColor Red
        Read-Host "Nhan Enter de thoat"
        exit 1
    }
}

# Trigger workflow
Write-Host "[3/5] Dang trigger GitHub Actions build..." -ForegroundColor Cyan
gh workflow run build-ios.yml -f version=$VERSION
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Trigger workflow that bai!" -ForegroundColor Red
    Write-Host "Kiem tra file .github/workflows/build-ios.yml da duoc push chua"
    Read-Host "Nhan Enter de thoat"
    exit 1
}

# Cho workflow bat dau
Write-Host "[4/5] Cho workflow bat dau..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# Hien thi thong tin
Write-Host "[5/5] Dang theo doi build status..." -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Workflow dang chay tren GitHub!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$url = gh run list --workflow=build-ios.yml --limit=1 --json url --jq ".[0].url"
Write-Host "Xem tien trinh tai: $url" -ForegroundColor Green
Write-Host ""
Write-Host "Theo doi live: gh run watch"
Write-Host "Hoac truy cap GitHub Actions tren browser."
Write-Host ""

# Hoi theo doi live
$watch = Read-Host "Theo doi build live? (y/n)"
if ($watch -eq "y") {
    Write-Host ""
    gh run watch

    # Sau khi build xong, hoi download
    Write-Host ""
    $download = Read-Host "Download IPA ve may? (y/n)"
    if ($download -eq "y") {
        Write-Host ""
        Write-Host "Dang download IPA..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Force -Path "build\output" | Out-Null

        # Lay run ID moi nhat
        $runId = gh run list --workflow=build-ios.yml --limit=1 --json databaseId --jq ".[0].databaseId"

        # Download artifact
        gh run download $runId -n "xiaophim-$VERSION-ios" -D build\output

        $ipaPath = "build\output\xiaophim-$VERSION-unsigned.ipa"
        if (Test-Path $ipaPath) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "  DOWNLOAD THANH CONG!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "File: $ipaPath" -ForegroundColor Green
            Write-Host ""
            Write-Host "Luu y: Day la file UNSIGNED IPA" -ForegroundColor Yellow
            Write-Host "Can ky lai bang provisioning profile de cai tren thiet bi"
            Write-Host ""
        } else {
            Write-Host "[ERROR] Khong tim thay file IPA!" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HOAN TAT!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Nhan Enter de thoat"
