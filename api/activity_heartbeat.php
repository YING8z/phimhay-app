<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
require_once dirname(__DIR__) . '/includes/config.php';

header('Content-Type: application/json; charset=utf-8');

if (!isLoggedIn() && !empty($_COOKIE[AUTH_COOKIE_NAME])) {
    restoreSessionFromToken();
}

$raw = file_get_contents('php://input');
$body = is_string($raw) && $raw !== '' ? json_decode($raw, true) : [];
$input = array_merge($_POST, $body);

$deviceId   = trim((string) ($input['device_id'] ?? ''));
$deviceModel = trim((string) ($input['device_model'] ?? ''));
$osVersion  = trim((string) ($input['os_version'] ?? ''));
$appVersion = trim((string) ($input['app_version'] ?? ''));
$platform   = trim((string) ($input['platform'] ?? 'ios'));
$movieId    = (int) ($input['movie_id'] ?? 0);
$episodeId  = (int) ($input['episode_id'] ?? 0);
$epSlug     = trim((string) ($input['ep_slug'] ?? ''));
$serverIdx  = (int) ($input['server_idx'] ?? 0);
$position   = max(0, (int) ($input['position'] ?? 0));
$duration   = max(0, (int) ($input['duration'] ?? 0));
$sourceType = trim((string) ($input['source_type'] ?? ''));

if (!in_array($platform, ['ios', 'android'])) {
    $platform = 'ios';
}

$userId = $_SESSION['user_id'] ?? null;
$ip = $_SERVER['REMOTE_ADDR'] ?? '';
$ua = mb_substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255);

$db = getDB();

// Update or insert mobile_app_sessions
try {
    if ($deviceId !== '') {
        $stmt = $db->prepare("
            SELECT id FROM mobile_app_sessions
            WHERE device_id = ? AND platform = ?
            ORDER BY last_heartbeat DESC LIMIT 1
        ");
        $stmt->execute([$deviceId, $platform]);
        $existing = $stmt->fetch();

        if ($existing) {
            $db->prepare("
                UPDATE mobile_app_sessions
                SET user_id=?, device_model=?, os_version=?, app_version=?, last_heartbeat=NOW(), ip_address=?
                WHERE id=?
            ")->execute([$userId, $deviceModel, $osVersion, $appVersion, $ip, $existing['id']]);
        } else {
            $db->prepare("
                INSERT INTO mobile_app_sessions (user_id, device_id, device_model, os_version, app_version, platform, last_heartbeat, ip_address)
                VALUES (?,?,?,?,?,?,NOW(),?)
            ")->execute([$userId, $deviceId, $deviceModel, $osVersion, $appVersion, $platform, $ip]);
        }
    }
} catch (Exception $e) {
    // Silent fail for session tracking
}

// Update watch_history with client_type = 'mobile' and platform if watching something
if ($movieId > 0) {
    try {
        $identity = watchProgressIdentity();
        if ($userId) {
            $stmt = $db->prepare("SELECT id FROM watch_history WHERE user_id=? AND movie_id=? ORDER BY id DESC LIMIT 1");
            $stmt->execute([$userId, $movieId]);
        } else {
            $stmt = $db->prepare("SELECT id FROM watch_history WHERE session_id=? AND user_id IS NULL AND movie_id=? ORDER BY id DESC LIMIT 1");
            $stmt->execute([$identity['session_id'], $movieId]);
        }
        $row = $stmt->fetch();
        if ($row) {
            $db->prepare("UPDATE watch_history SET client_type='mobile', platform=COALESCE(NULLIF(?, ''), platform) WHERE id=? AND (client_type IS NULL OR client_type='' OR platform IS NULL)")
                ->execute([$platform, $row['id']]);
        }
    } catch (Exception $e) {
        // Silent fail
    }
}

echo json_encode(['success' => true]);
