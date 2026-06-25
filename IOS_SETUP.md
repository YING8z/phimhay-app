# iOS Setup - Firebase Cloud Messaging

## Bước 1: Tạo iOS platform cho project Flutter

```bash
cd C:\xampp\htdocs\phimhay_app
flutter create --platforms=ios .
```

## Bước 2: Thêm app iOS vào Firebase Console

1. Vào Firebase Console → Project Settings → **Add app** → iOS
2. Bundle ID: `com.phimhay.phimhayApp`
3. App nickname: `PhimHay iOS`
4. Download `GoogleService-Info.plist`

## Bước 3: Đặt GoogleService-Info.plist

Copy file đã download vào:
```
phimhay_app/ios/Runner/GoogleService-Info.plist
```

## Bước 4: Thêm vào Xcode project

Mở `ios/Runner.xcworkspace` bằng Xcode, click chuột phải vào `Runner` → **Add Files to "Runner"** → chọn `GoogleService-Info.plist` → tick **Copy items if needed** và **Create groups**.

## Bước 5: Kiểm tra Podfile

Mở `ios/Podfile`, đảm bảo:
```ruby
platform :ios, '13.0'
```

## Bước 6: Thêm Push Notification capability (Xcode)

1. Mở `ios/Runner.xcworkspace` trong Xcode
2. Chọn Runner → **Signing & Capabilities** → **+ Capability** → **Push Notifications**
3. **Background Modes** → tick **Remote notifications**

## Bước 7: Enable push notification trong App Delegate

Mở `ios/Runner/AppDelegate.swift`, thêm vào:

```swift
import UIKit
import Flutter
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // For iOS 10+ notification permission
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    completionHandler(UIBackgroundFetchResult.newData)
  }
}
```

## Bước 8: Chạy pod install

```bash
cd ios
pod install
cd ..
```

## Bước 9: Build iOS

```bash
flutter build ios --release
```