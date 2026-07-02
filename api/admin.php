<?php
/**
 * Admin page — Cập nhật version app
 * Truy cập: /api/app_update/admin.php
 * Bảo vệ bằng password đơn giản
 */

$ADMIN_PASSWORD = 'admin'; // Đổi password này

session_start();
$isLoggedIn = !empty($_SESSION['app_update_admin']);

// Xử lý login
if (isset($_POST['password'])) {
    if ($_POST['password'] === $ADMIN_PASSWORD) {
        $_SESSION['app_update_admin'] = true;
        $isLoggedIn = true;
    } else {
        $error = 'Sai password';
    }
}

// Xử lý logout
if (isset($_GET['logout'])) {
    unset($_SESSION['app_update_admin']);
    $isLoggedIn = false;
}

$configFile = __DIR__ . '/versions.json';
$config = file_exists($configFile) ? json_decode(file_get_contents($configFile), true) : [];

// Auto-detect version từ file APK/IPA trong thư mục downloads
function detectVersions() {
    $downloadsDir = realpath(__DIR__ . '/../../Downloads');
    if (!$downloadsDir) $downloadsDir = realpath(__DIR__ . '/../../downloads');
    if (!$downloadsDir) return ['android' => [], 'ios' => []];

    $result = ['android' => [], 'ios' => []];
    $files = glob($downloadsDir . '/xiaophim-*.*');

    foreach ($files as $file) {
        $filename = basename($file);
        // Match: xiaophim-3.3.0.apk hoặc xiaophim-3.3.0.ipa
        if (preg_match('/xiaophim-([\d.]+)\.(apk|ipa)$/i', $filename, $m)) {
            $version = $m[1];
            $ext = strtolower($m[2]);
            $platform = $ext === 'apk' ? 'android' : 'ios';
            $mtime = filemtime($file);

            $result[$platform][] = [
                'version' => $version,
                'file' => $filename,
                'path' => $file,
                'size' => round(filesize($file) / 1024 / 1024, 1) . ' MB',
                'mtime' => $mtime,
                'date' => date('Y-m-d H:i', $mtime),
            ];
        }
    }

    // Sắp xếp theo version mới nhất
    foreach ($result as $p => &$items) {
        usort($items, function($a, $b) {
            return version_compare($b['version'], $a['version']);
        });
    }

    return $result;
}

// Xóa file
if ($isLoggedIn && isset($_GET['delete'])) {
    $deleteFile = $_GET['delete'];
    $downloadsDir = realpath(__DIR__ . '/../../Downloads');
    if (!$downloadsDir) $downloadsDir = realpath(__DIR__ . '/../../downloads');
    $fullPath = realpath($downloadsDir . '/' . basename($deleteFile));

    // Chỉ cho phép xóa file xiaophim-* trong thư mục downloads
    if ($fullPath && strpos($fullPath, $downloadsDir) === 0 && preg_match('/xiaophim-/', basename($fullPath))) {
        unlink($fullPath);
        $success = "Đã xóa: " . basename($fullPath);
    }
}

$detected = $isLoggedIn ? detectVersions() : [];

// Xử lý cập nhật
$success = '';
if ($isLoggedIn && $_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['platform'])) {
    $platform = $_POST['platform'];
    $version = trim($_POST['version'] ?? '');
    $notes = trim($_POST['notes'] ?? '');
    $force = isset($_POST['force']);
    $minSupported = trim($_POST['min_supported'] ?? '3.0.0');

    if (!empty($version) && in_array($platform, ['android', 'ios'])) {
        // Tạo URL download tự động theo version
        $ext = $platform === 'android' ? 'apk' : 'ipa';
        $url = "https://xiaofilm.online/downloads/xiaophim-{$version}.{$ext}";

        $config[$platform] = [
            'latest' => $version,
            'url' => $url,
            'notes' => $notes,
            'force' => $force,
            'min_supported' => $minSupported,
        ];

        file_put_contents($configFile, json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        $success = "Đã cập nhật {$platform} → v{$version}";
    }
}
?>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>App Update Admin</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, system-ui, sans-serif; background: #0D0F14; color: #fff; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { font-size: 24px; margin-bottom: 20px; color: #E11D48; }
        .card { background: #1A1C21; border-radius: 12px; padding: 20px; margin-bottom: 20px; border: 1px solid rgba(255,255,255,0.08); }
        .card h2 { font-size: 16px; margin-bottom: 16px; color: #E11D48; }
        label { display: block; font-size: 13px; color: rgba(255,255,255,0.7); margin-bottom: 6px; margin-top: 12px; }
        input[type="text"], input[type="password"], textarea { width: 100%; padding: 10px 12px; background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; color: #fff; font-size: 14px; }
        textarea { min-height: 80px; resize: vertical; }
        input:focus, textarea:focus { outline: none; border-color: #E11D48; }
        .checkbox-row { display: flex; align-items: center; gap: 8px; margin-top: 12px; }
        .checkbox-row input { width: 18px; height: 18px; }
        button { padding: 12px 24px; background: #E11D48; color: #fff; border: none; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; margin-top: 16px; width: 100%; }
        button:hover { background: #BE123C; }
        .success { background: #065F46; color: #A7F3D0; padding: 12px; border-radius: 8px; margin-bottom: 16px; }
        .error { background: #7F1D1D; color: #FCA5A5; padding: 12px; border-radius: 8px; margin-bottom: 16px; }
        .current { font-size: 13px; color: rgba(255,255,255,0.5); margin-top: 4px; }
        .logout { color: rgba(255,255,255,0.5); font-size: 13px; text-decoration: none; float: right; }
        .logout:hover { color: #fff; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📱 App Update Admin</h1>

        <?php if (!$isLoggedIn): ?>
        <!-- Login -->
        <div class="card">
            <h2>Đăng nhập</h2>
            <?php if (!empty($error)): ?><div class="error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
            <form method="POST">
                <label>Password</label>
                <input type="password" name="password" placeholder="Nhập password..." autofocus>
                <button type="submit">Đăng nhập</button>
            </form>
        </div>

        <?php else: ?>
        <!-- Admin -->
        <a href="?logout=1" class="logout">Đăng xuất</a>

        <?php if (!empty($success)): ?><div class="success">✅ <?= htmlspecialchars($success) ?></div><?php endif; ?>

        <!-- Auto-detected versions -->
        <?php if (!empty($detected['android']) || !empty($detected['ios'])): ?>
        <div class="card">
            <h2>📦 File trong Downloads</h2>
            <?php foreach (['android' => '🤖 Android', 'ios' => '🍎 iOS'] as $p => $label): ?>
              <?php if (!empty($detected[$p])): ?>
                <div style="margin-bottom:16px;">
                  <strong><?= $label ?></strong>
                  <?php foreach ($detected[$p] as $i => $d): ?>
                    <div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0 8px 16px;<?= $i > 0 ? 'opacity:0.6' : '' ?>">
                      <div>
                        v<?= htmlspecialchars($d['version']) ?>
                        <?php if ($i === 0): ?><span style="color:#22c55e;font-size:11px;">(mới nhất)</span><?php endif; ?>
                        <span style="color:rgba(255,255,255,0.4);font-size:12px;">(<?= $d['size'] ?>, <?= $d['date'] ?>)</span>
                        <div style="font-size:11px;color:rgba(255,255,255,0.3);"><?= htmlspecialchars($d['file']) ?></div>
                      </div>
                      <div style="display:flex;gap:6px;">
                        <?php if ($i === 0): ?>
                        <form method="POST" style="margin:0;">
                          <input type="hidden" name="platform" value="<?= $p ?>">
                          <input type="hidden" name="version" value="<?= htmlspecialchars($d['version']) ?>">
                          <input type="hidden" name="notes" value="<?= htmlspecialchars($config[$p]['notes'] ?? '') ?>">
                          <input type="hidden" name="min_supported" value="<?= htmlspecialchars($config[$p]['min_supported'] ?? '3.0.0') ?>">
                          <?php if (!empty($config[$p]['force'])): ?><input type="hidden" name="force" value="on"><?php endif; ?>
                          <button type="submit" style="width:auto;padding:6px 12px;margin:0;font-size:11px;">Áp dụng</button>
                        </form>
                        <?php endif; ?>
                        <a href="?delete=<?= urlencode($d['file']) ?>"
                           onclick="return confirm('Xóa <?= htmlspecialchars($d['file']) ?>?')"
                           style="padding:6px 10px;background:#7F1D1D;color:#FCA5A5;border-radius:6px;font-size:11px;text-decoration:none;">Xóa</a>
                      </div>
                    </div>
                  <?php endforeach; ?>
                </div>
              <?php endif; ?>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>

        <!-- Android -->
        <div class="card">
            <h2>🤖 Android</h2>
            <form method="POST">
                <input type="hidden" name="platform" value="android">
                <label>Version mới</label>
                <input type="text" name="version" placeholder="3.3.0" value="<?= htmlspecialchars($config['android']['latest'] ?? '') ?>" required>
                <div class="current">Hiện tại: <?= htmlspecialchars($config['android']['latest'] ?? 'chưa có') ?></div>

                <label>Download URL (tự tạo)</label>
                <div class="current">https://xiaofilm.online/downloads/xiaophim-{version}.apk</div>

                <label>Ghi chú cập nhật</label>
                <textarea name="notes" placeholder="- Fix lỗi video&#10;- Thêm tính năng mới"><?= htmlspecialchars($config['android']['notes'] ?? '') ?></textarea>

                <label>Version tối thiểu</label>
                <input type="text" name="min_supported" value="<?= htmlspecialchars($config['android']['min_supported'] ?? '3.0.0') ?>">

                <div class="checkbox-row">
                    <input type="checkbox" name="force" id="force-android" <?= ($config['android']['force'] ?? false) ? 'checked' : '' ?>>
                    <label for="force-android" style="margin:0">Bắt buộc cập nhật</label>
                </div>

                <button type="submit">Cập nhật Android</button>
            </form>
        </div>

        <!-- iOS -->
        <div class="card">
            <h2>🍎 iOS</h2>
            <form method="POST">
                <input type="hidden" name="platform" value="ios">
                <label>Version mới</label>
                <input type="text" name="version" placeholder="3.3.0" value="<?= htmlspecialchars($config['ios']['latest'] ?? '') ?>" required>
                <div class="current">Hiện tại: <?= htmlspecialchars($config['ios']['latest'] ?? 'chưa có') ?></div>

                <label>Download URL (tự tạo)</label>
                <div class="current">https://xiaofilm.online/downloads/xiaophim-{version}.ipa</div>

                <label>Ghi chú cập nhật</label>
                <textarea name="notes" placeholder="- Fix lỗi video&#10;- Thêm tính năng mới"><?= htmlspecialchars($config['ios']['notes'] ?? '') ?></textarea>

                <label>Version tối thiểu</label>
                <input type="text" name="min_supported" value="<?= htmlspecialchars($config['ios']['min_supported'] ?? '3.0.0') ?>">

                <div class="checkbox-row">
                    <input type="checkbox" name="force" id="force-ios" <?= ($config['ios']['force'] ?? false) ? 'checked' : '' ?>>
                    <label for="force-ios" style="margin:0">Bắt buộc cập nhật</label>
                </div>

                <button type="submit">Cập nhật iOS</button>
            </form>
        </div>

        <!-- Current config -->
        <div class="card">
            <h2>📋 Config hiện tại</h2>
            <pre style="font-size:12px; color:rgba(255,255,255,0.6); overflow-x:auto;"><?= htmlspecialchars(json_encode($config, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)) ?></pre>
        </div>
        <?php endif; ?>
    </div>
</body>
</html>
