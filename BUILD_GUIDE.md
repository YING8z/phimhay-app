# iOS Build Tool cho Windows

Tool tự động build iOS IPA từ dự án Flutter trên Windows thông qua GitHub Actions.

## Yêu cầu

1. **Git**: [Download Git](https://git-scm.com/download/win)
2. **GitHub CLI**: Cài đặt qua winget:
   ```cmd
   winget install --id GitHub.cli
   ```
   Hoặc download tại: https://cli.github.com/

3. **GitHub Account** và repository đã tạo

## Cách sử dụng

### Bước 1: Setup lần đầu

1. Đăng nhập GitHub CLI:
   ```cmd
   gh auth login
   ```

2. Tạo repository trên GitHub (nếu chưa có):
   ```cmd
   gh repo create phimhay-app --public
   ```

3. Push code lên GitHub lần đầu:
   ```cmd
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/phimhay-app.git
   git push -u origin main
   ```

### Bước 2: Build iOS

Chạy file `build-ios-windows.bat`:

```cmd
build-ios-windows.bat
```

Tool sẽ tự động:
1. ✅ Commit code hiện tại
2. ✅ Push lên GitHub
3. ✅ Trigger GitHub Actions build trên macOS
4. ✅ Theo dõi tiến trình build
5. ✅ Download IPA về máy khi xong

### Bước 3: Upload lên Server (Tùy chọn)

Nếu muốn tự động upload IPA lên server, cần setup secrets trên GitHub:

#### Với FTP:
```cmd
gh secret set FTP_SERVER -b "ftp.yourserver.com"
gh secret set FTP_USERNAME -b "your_username"
gh secret set FTP_PASSWORD -b "your_password"
```

#### Với SFTP:
```cmd
gh secret set SFTP_HOST -b "your-server.com"
gh secret set SFTP_USERNAME -b "your_username"
gh secret set SFTP_PASSWORD -b "your_password"
gh secret set SFTP_PORT -b "22"
```

#### Với Custom API:
```cmd
gh secret set UPLOAD_API_URL -b "https://api.yourserver.com/upload"
gh secret set API_TOKEN -b "your_api_token"
```

## Output

File IPA sẽ được lưu tại:
- **GitHub Artifacts**: Lưu 30 ngày
- **GitHub Releases**: Nếu push tag (vd: `v3.3.6`)
- **Local**: `build/output/xiaophim-{version}-unsigned.ipa`

## Lưu ý quan trọng

⚠️ **File IPA là UNSIGNED** - Không thể cài trực tiếp lên thiết bị iOS.

Để sử dụng được, cần:
1. **Ký lại với provisioning profile** (cần Apple Developer Account)
2. Hoặc upload lên **TestFlight** / **App Store Connect**
3. Hoặc dùng **enterprise distribution certificate**

## Code Signing (Nâng cao)

Nếu có Apple Developer Account, thêm secrets để tự động ký:

```cmd
gh secret set APPLE_CERTIFICATE_BASE64 -b "$(cat certificate.p12 | base64)"
gh secret set APPLE_CERT_PASSWORD -b "your_cert_password"
gh secret set APPLE_PROVISIONING_PROFILE_BASE64 -b "$(cat profile.mobileprovision | base64)"
gh secret set APPLE_TEAM_ID -b "YOUR_TEAM_ID"
```

Sau đó cập nhật workflow để thêm bước code signing.

## Troubleshooting

### Lỗi: "workflow not found"
- Đảm bảo đã push file `.github/workflows/build-ios.yml` lên GitHub
- Kiểm tra GitHub Actions có enabled không: Settings → Actions → Allow all actions

### Lỗi: "authentication failed"
- Chạy lại: `gh auth login`

### Build lâu quá?
- GitHub Actions free tier: 2000 phút/tháng
- Build iOS thường mất 10-15 phút

## Liên hệ

Có vấn đề? Tạo issue trên GitHub repository.
