# iOS Build Tool - Windows

## 📦 Tạo file IPA từ Flutter trên Windows (không cần macOS)

Tool này cho phép bạn build iOS IPA từ dự án Flutter trên Windows thông qua GitHub Actions macOS runner.

## 🎯 Tính năng

✅ Build iOS IPA hoàn toàn trên Windows  
✅ Không cần máy Mac hay Hackintosh  
✅ Tự động commit, push, trigger build  
✅ Theo dõi tiến trình build real-time  
✅ Download IPA tự động về máy  
✅ Tùy chọn: Upload IPA lên server qua FTP/SFTP/API  

## ⚡ Quick Start

### 1. Cài đặt yêu cầu

```cmd
# Cài Git (nếu chưa có)
winget install --id Git.Git

# Cài GitHub CLI
winget install --id GitHub.cli

# Login GitHub
gh auth login
```

### 2. Setup repository

```cmd
# Nếu chưa có remote
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Push code lần đầu
git add .
git commit -m "Add iOS build workflow"
git push -u origin main
```

### 3. Build iOS

```cmd
# Chạy tool
build-ios-windows.bat

# Nhập version khi được hỏi (vd: 3.3.6)
```

Xong! Tool sẽ tự động build trên GitHub Actions và download IPA về.

## 📁 Cấu trúc

```
.github/workflows/
  ├── build-ios.yml           # Workflow build iOS
  └── upload-to-server.yml    # Workflow upload lên server (optional)
build-ios-windows.bat         # Tool chính
BUILD_GUIDE.md                # Hướng dẫn chi tiết
```

## ⚙️ Tự động upload lên server (Optional)

Setup secrets trên GitHub:

```cmd
# FTP
gh secret set FTP_SERVER -b "ftp.yourserver.com"
gh secret set FTP_USERNAME -b "username"
gh secret set FTP_PASSWORD -b "password"

# Hoặc SFTP
gh secret set SFTP_HOST -b "server.com"
gh secret set SFTP_USERNAME -b "username"
gh secret set SFTP_PASSWORD -b "password"

# Hoặc Custom API
gh secret set UPLOAD_API_URL -b "https://api.server.com/upload"
gh secret set API_TOKEN -b "your_token"
```

## ⚠️ Lưu ý quan trọng

**File IPA output là UNSIGNED** - không thể cài trực tiếp lên iPhone.

Để cài được, cần:
- Ký lại với provisioning profile (cần Apple Developer Account $99/năm)
- Hoặc upload lên TestFlight
- Hoặc dùng enterprise certificate

## 🔧 Advanced: Code Signing

Nếu có Apple Developer Account, thêm secrets để tự động ký:

```cmd
gh secret set APPLE_CERTIFICATE_BASE64
gh secret set APPLE_CERT_PASSWORD
gh secret set APPLE_PROVISIONING_PROFILE_BASE64
gh secret set APPLE_TEAM_ID
```

Sau đó sửa workflow để thêm signing step.

## 💰 Chi phí

- GitHub Actions: **MIỄN PHÍ** 2000 phút/tháng
- Mỗi build iOS: ~10-15 phút
- → Có thể build ~130-200 lần/tháng miễn phí

## 📊 Output

IPA sẽ được lưu:
- GitHub Artifacts (30 ngày)
- Local: `build/output/xiaophim-{version}-unsigned.ipa`
- Server của bạn (nếu setup upload)

## 🐛 Troubleshooting

**"workflow not found"**  
→ Đảm bảo file `.github/workflows/build-ios.yml` đã được push

**"authentication failed"**  
→ Chạy: `gh auth login`

**Build thất bại**  
→ Xem logs tại: `gh run list` hoặc trên GitHub web

## 📝 License

MIT - Free to use
