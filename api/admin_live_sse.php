<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
require_once dirname(__DIR__) . '/includes/config.php';

if (!isLoggedIn()) {
    http_response_code(401);
    exit;
}
if (!isAdmin()) {
    http_response_code(403);
    exit;
}

header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('X-Accel-Buffering: no');

$db = getDB();

function sendSSE($event, $data) {
    echo "event: {$event}\n";
    echo "data: " . json_encode($data, JSON_UNESCAPED_UNICODE) . "\n\n";
    if (ob_get_level()) ob_flush();
    flush();
}

function getLiveData(PDO $db): array {
    // ── Đang xem: Web ──
    $watchingWeb = (int) $db->query("
        SELECT COUNT(DISTINCT COALESCE(CAST(user_id AS CHAR), session_id))
        FROM watch_history
        WHERE watched_at >= NOW() - INTERVAL 5 MINUTE
          AND (client_type IS NULL OR client_type = '' OR client_type = 'web')
    ")->fetchColumn();

    // ── Đang xem: Mobile total ──
    $mobileWatchingTotal = (int) $db->query("
        SELECT COUNT(DISTINCT COALESCE(CAST(user_id AS CHAR), session_id))
        FROM watch_history
        WHERE watched_at >= NOW() - INTERVAL 5 MINUTE AND client_type = 'mobile'
    ")->fetchColumn();

    // ── Mobile online by platform ──
    $iosOnline = (int) $db->query("SELECT COUNT(*) FROM mobile_app_sessions WHERE platform='ios' AND last_heartbeat >= NOW() - INTERVAL 5 MINUTE")->fetchColumn();
    $iosOnline30m = (int) $db->query("SELECT COUNT(*) FROM mobile_app_sessions WHERE platform='ios' AND last_heartbeat >= NOW() - INTERVAL 30 MINUTE")->fetchColumn();
    $androidOnline = (int) $db->query("SELECT COUNT(*) FROM mobile_app_sessions WHERE platform='android' AND last_heartbeat >= NOW() - INTERVAL 5 MINUTE")->fetchColumn();
    $androidOnline30m = (int) $db->query("SELECT COUNT(*) FROM mobile_app_sessions WHERE platform='android' AND last_heartbeat >= NOW() - INTERVAL 30 MINUTE")->fetchColumn();

    // ── Currently watching detail: Web ──
    $watchingWebList = $db->query("
        SELECT wh.id, wh.user_id,
               COALESCE(u.username, CONCAT('Guest #', LEFT(wh.session_id, 6))) AS viewer_name,
               m.name AS movie_name, m.slug AS movie_slug,
               COALESCE(e.ep_name, wh.ep_slug) AS ep_name,
               wh.server_idx, wh.watch_time, wh.duration_seconds, wh.source_type,
               TIMESTAMPDIFF(SECOND, wh.watched_at, NOW()) AS seconds_ago
        FROM watch_history wh
        INNER JOIN (
            SELECT COALESCE(CAST(user_id AS CHAR), session_id) AS vk, MAX(id) AS mid
            FROM watch_history
            WHERE watched_at >= NOW() - INTERVAL 5 MINUTE
              AND (client_type IS NULL OR client_type = '' OR client_type = 'web')
            GROUP BY vk
        ) t ON wh.id = t.mid
        LEFT JOIN users u ON wh.user_id = u.id
        LEFT JOIN movies m ON wh.movie_id = m.id
        LEFT JOIN episodes e ON e.id = wh.episode_id
        ORDER BY wh.watched_at DESC
    ")->fetchAll();

    // ── Currently watching detail: Mobile ──
    $watchingMobileList = $db->query("
        SELECT wh.id, wh.user_id,
               COALESCE(u.username, CONCAT('Guest #', LEFT(wh.session_id, 6))) AS viewer_name,
               m.name AS movie_name, m.slug AS movie_slug,
               COALESCE(e.ep_name, wh.ep_slug) AS ep_name,
               wh.server_idx, wh.watch_time, wh.duration_seconds, wh.source_type,
               TIMESTAMPDIFF(SECOND, wh.watched_at, NOW()) AS seconds_ago,
               COALESCE(wh.platform, 'mobile') AS platform
        FROM watch_history wh
        INNER JOIN (
            SELECT COALESCE(CAST(user_id AS CHAR), session_id) AS vk, MAX(id) AS mid
            FROM watch_history
            WHERE watched_at >= NOW() - INTERVAL 5 MINUTE AND client_type = 'mobile'
            GROUP BY vk
        ) t ON wh.id = t.mid
        LEFT JOIN users u ON wh.user_id = u.id
        LEFT JOIN movies m ON wh.movie_id = m.id
        LEFT JOIN episodes e ON e.id = wh.episode_id
        ORDER BY wh.watched_at DESC
    ")->fetchAll();

    $total = $watchingWeb + $mobileWatchingTotal;

    return [
        'total' => $total,
        'watching_web' => $watchingWeb,
        'watching_mobile_total' => $mobileWatchingTotal,
        'ios_online_5m' => $iosOnline,
        'ios_online_30m' => $iosOnline30m,
        'android_online_5m' => $androidOnline,
        'android_online_30m' => $androidOnline30m,
        'watching_web_list' => $watchingWebList,
        'watching_mobile_list' => $watchingMobileList,
        'timestamp' => time(),
    ];
}

$startTime = time();
$maxDuration = 120;

while ((time() - $startTime) < $maxDuration) {
    $data = getLiveData($db);
    sendSSE('update', $data);

    for ($i = 0; $i < 5; $i++) {
        if (connection_aborted()) break;
        sleep(1);
    }
    if (connection_aborted()) break;

    try { $db->query("SELECT 1"); } catch (Exception $e) { $db = getDB(); }
}

sendSSE('close', ['reason' => 'timeout']);
