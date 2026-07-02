<?php
/**
 * Hybrid Ad Marker Detection System
 *
 * Layer 1: Query DB for existing markers (crowdsource)
 * Layer 2: Parse m3u8 with enhanced patterns + EXT-X-DISCONTINUITY
 * Layer 3: Store results in DB for future requests
 *
 * API Endpoints:
 * - GET ?url=X&movie_id=Y&server_name=Z → Get markers (hybrid detection)
 * - POST ?action=report → Submit false positive/negative report
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST');
header('Access-Control-Allow-Headers: Content-Type');

define('INCLUDED', true);
require_once __DIR__ . '/../includes/config.php';

$db = getDB();
if (!$db) {
    echo json_encode(['error' => 'Database connection failed', 'ads' => []]);
    exit;
}

// Handle POST requests (reports)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? $_GET['action'] ?? '';

    if ($action === 'report') {
        $movie_id = (int)($_POST['movie_id'] ?? 0);
        $server_name = $_POST['server_name'] ?? '';
        $report_type = $_POST['report_type'] ?? ''; // false_positive, false_negative, missed_ad
        $start_time = (int)($_POST['start_time'] ?? 0);
        $user_ip = $_SERVER['REMOTE_ADDR'] ?? '';

        if (!$movie_id || !$server_name || !$report_type) {
            echo json_encode(['success' => false, 'error' => 'Missing required fields']);
            exit;
        }

        // Insert report
        $stmt = $db->prepare("INSERT INTO ad_reports (movie_id, server_name, report_type, start_time, user_ip) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$movie_id, $server_name, $report_type, $start_time ?: null, $user_ip]);

        // If false positive, decrement confidence of that marker
        if ($report_type === 'false_positive' && $start_time > 0) {
            $stmt = $db->prepare("UPDATE ad_markers SET false_reports = false_reports + 1, confidence = GREATEST(0, confidence - 0.1) WHERE movie_id = ? AND server_name = ? AND start_time = ?");
            $stmt->execute([$movie_id, $server_name, $start_time]);
        }

        echo json_encode(['success' => true, 'message' => 'Report submitted']);
        exit;
    }

    echo json_encode(['success' => false, 'error' => 'Invalid action']);
    exit;
}

// Handle GET requests (fetch markers)
$url = $_GET['url'] ?? '';
$movie_id = (int)($_GET['movie_id'] ?? 0);
$server_name = $_GET['server_name'] ?? '';

if (empty($url)) {
    echo json_encode(['error' => 'Missing url parameter', 'ads' => []]);
    exit;
}

if (!$movie_id || !$server_name) {
    echo json_encode(['error' => 'Missing movie_id or server_name', 'ads' => []]);
    exit;
}

$m3u8_hash = md5($url);

// ============ LAYER 1: Check DB for existing markers ============
$stmt = $db->prepare("SELECT start_time, duration, confidence, report_count FROM ad_markers WHERE movie_id = ? AND server_name = ? AND confidence > 0.3 ORDER BY start_time");
$stmt->execute([$movie_id, $server_name]);
$db_markers = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (count($db_markers) > 0) {
    // Found markers in DB, return them
    $ads = array_map(function($m) {
        return [
            'start_time' => (int)$m['start_time'],
            'duration' => (int)$m['duration'],
            'confidence' => (float)$m['confidence'],
            'source' => 'database'
        ];
    }, $db_markers);

    echo json_encode([
        'success' => true,
        'ads' => $ads,
        'total_duration' => 0, // Not stored in DB
        'url' => $url,
        'layer' => 1,
        'message' => 'Retrieved from crowdsource database'
    ]);
    exit;
}

// ============ LAYER 2: Parse m3u8 with enhanced detection ============
function fetchUrl($url) {
    $ctx = stream_context_create([
        'http' => [
            'timeout' => 10,
            'header' => "Referer: https://xiaofilm.online\r\nUser-Agent: Mozilla/5.0\r\n",
        ],
        'ssl' => ['verify_peer' => false, 'verify_peer_name' => false],
    ]);
    return @file_get_contents($url, false, $ctx);
}

function isAdSegment($segUrl) {
    // Enhanced patterns from various sources
    $patterns = [
        '/v8/', '/v7/', '/v9/', '/v10/', 'convertv8/', 'convertv7/',
        '/adjump/', '/ad/', '/ads/', 'segment_0', 'ad_', '/ts/ad',
        'preroll', 'midroll', 'sponsor', 'x-ads-', 'discontinuity-',
        '/cdn-ad/', '/video-ad/'
    ];

    foreach ($patterns as $p) {
        if (stripos($segUrl, $p) !== false) return true;
    }
    return false;
}

// Fetch the m3u8 playlist
$content = fetchUrl($url);
if ($content === false) {
    echo json_encode(['error' => 'Failed to fetch m3u8', 'url' => $url, 'ads' => [], 'layer' => 2]);
    exit;
}

// If master playlist → get variant
if (strpos($content, '#EXT-X-STREAM-INF') !== false) {
    $lines = explode("\n", trim($content));
    foreach ($lines as $line) {
        $line = trim($line);
        if (!empty($line) && $line[0] !== '#' && strpos($line, '.m3u8') !== false) {
            if (strpos($line, 'http') === 0) {
                $variantUrl = $line;
            } elseif (strpos($line, '/') === 0) {
                $parsed = parse_url($url);
                $variantUrl = $parsed['scheme'] . '://' . $parsed['host'] . $line;
            } else {
                $variantUrl = rtrim(dirname($url), '/') . '/' . $line;
            }
            $content = fetchUrl($variantUrl);
            $url = $variantUrl;
            break;
        }
    }
}

if (empty($content)) {
    echo json_encode(['error' => 'Empty playlist', 'url' => $url, 'ads' => [], 'layer' => 2]);
    exit;
}

// ═══════════════════════════════════════════════════════════════════
// Parse m3u8 — TWO complementary detectors combined:
//
// 1. EXT-X-DISCONTINUITY: HLS standard tag marking content breaks.
//    Ad segments sit between consecutive DISCONTINUITY tags.
//    This is the PRIMARY and most reliable method.
//
// 2. URL pattern matching: fallback for servers that embed ads
//    without DISCONTINUITY tags.
// ═══════════════════════════════════════════════════════════════════
$lines = explode("\n", trim($content));
$cumulative = 0.0;
$ads = [];
$adBlockStart = null;
$inDiscontinuityBlock = false;
$discontinuityStart = 0;
$discAdStart = null; // URL-pattern ad start inside discontinuity block

for ($i = 0; $i < count($lines); $i++) {
    $line = trim($lines[$i]);

    // ── Track EXT-X-DISCONTINUITY markers ──
    if ($line === '#EXT-X-DISCONTINUITY') {
        if (!$inDiscontinuityBlock) {
            // Entering a discontinuity block (potential ad start)
            $inDiscontinuityBlock = true;
            $discontinuityStart = $cumulative;
            $discAdStart = null;
        } else {
            // Exiting discontinuity block — close any open ad
            if ($discAdStart !== null) {
                $blockDur = $cumulative - $discAdStart;
                if ($blockDur > 0) {
                    $ads[] = [
                        'start_time' => (int)round($discAdStart),
                        'duration' => (int)round($blockDur),
                        'confidence' => 1.0,
                        'source' => 'discontinuity+parsed'
                    ];
                }
                $discAdStart = null;
            } else {
                // No URL-pattern ad inside discontinuity → use discontinuity range
                $blockDur = $cumulative - $discontinuityStart;
                if ($blockDur >= 5) {
                    $ads[] = [
                        'start_time' => (int)round($discontinuityStart),
                        'duration' => (int)round($blockDur),
                        'confidence' => 0.9,
                        'source' => 'discontinuity'
                    ];
                }
            }
            $inDiscontinuityBlock = false;
        }
        continue;
    }

    // ── Track EXT-X-DATERANGE with ad-related attributes ──
    if (strpos($line, '#EXT-X-DATERANGE:') === 0) {
        if (preg_match('/CLASS="?AD/i', $line) || preg_match('/X-AD/i', $line)) {
            if ($adBlockStart === null) $adBlockStart = $cumulative;
        }
        continue;
    }

    // ── Parse EXTINF duration ──
    if (strpos($line, '#EXTINF:') !== 0) continue;

    if (preg_match('/#EXTINF:([\d.]+)/', $line, $m)) {
        $dur = floatval($m[1]);
    } else {
        $dur = 10.0;
    }

    // Next line is segment URL
    $segUrl = ($i + 1 < count($lines)) ? trim($lines[$i + 1]) : '';
    if (empty($segUrl) || $segUrl[0] === '#') {
        $cumulative += $dur;
        continue;
    }

    // Make absolute URL if relative
    if (strpos($segUrl, 'http') === 0) {
        // Already absolute
    } elseif (strpos($segUrl, '/') === 0) {
        // Absolute path (/adjump/...) → relative to domain root
        $parsed = parse_url($url);
        $segUrl = $parsed['scheme'] . '://' . $parsed['host'] . $segUrl;
    } else {
        // Relative path → relative to current directory
        $segUrl = rtrim(dirname($url), '/') . '/' . $segUrl;
    }

    // ── URL pattern matching — always run, even inside discontinuity ──
    $isAd = isAdSegment($segUrl);

    if ($inDiscontinuityBlock) {
        // Inside discontinuity block: track URL-pattern ad start
        if ($isAd) {
            if ($discAdStart === null) $discAdStart = $cumulative;
        } else {
            // Non-ad segment inside discontinuity → close any open ad
            if ($discAdStart !== null) {
                $blockDur = $cumulative - $discAdStart;
                if ($blockDur > 0) {
                    $ads[] = [
                        'start_time' => (int)round($discAdStart),
                        'duration' => (int)round($blockDur),
                        'confidence' => 1.0,
                        'source' => 'discontinuity+parsed'
                    ];
                }
                $discAdStart = null;
            }
        }
    } else {
        // Outside discontinuity: original URL-pattern logic
        if ($isAd) {
            if ($adBlockStart === null) $adBlockStart = $cumulative;
        } else {
            if ($adBlockStart !== null) {
                $blockDur = $cumulative - $adBlockStart;
                if ($blockDur > 0) {
                    $ads[] = [
                        'start_time' => (int)round($adBlockStart),
                        'duration' => (int)round($blockDur),
                        'confidence' => 1.0,
                        'source' => 'parsed'
                    ];
                }
                $adBlockStart = null;
            }
        }
    }

    $cumulative += $dur;
}

// ── Close any open blocks ──
if ($inDiscontinuityBlock) {
    if ($discAdStart !== null) {
        $blockDur = $cumulative - $discAdStart;
        if ($blockDur > 0) {
            $ads[] = [
                'start_time' => (int)round($discAdStart),
                'duration' => (int)round($blockDur),
                'confidence' => 1.0,
                'source' => 'discontinuity+parsed'
            ];
        }
    } else {
        $blockDur = $cumulative - $discontinuityStart;
        if ($blockDur >= 5) {
            $ads[] = [
                'start_time' => (int)round($discontinuityStart),
                'duration' => (int)round($blockDur),
                'confidence' => 0.9,
                'source' => 'discontinuity'
            ];
        }
    }
}
if ($adBlockStart !== null) {
    $blockDur = $cumulative - $adBlockStart;
    if ($blockDur > 0) {
        $ads[] = [
            'start_time' => (int)round($adBlockStart),
            'duration' => (int)round($blockDur),
            'confidence' => 1.0,
            'source' => 'parsed'
        ];
    }
}

// ── Merge overlapping ad blocks (prefer URL-pattern start times) ──
if (count($ads) > 1) {
    usort($ads, function($a, $b) { return $a['start_time'] - $b['start_time']; });
    $merged = [$ads[0]];
    for ($j = 1; $j < count($ads); $j++) {
        $last = end($merged);
        $curr = $ads[$j];
        // Overlap or gap < 3s → merge
        if ($curr['start_time'] <= $last['start_time'] + $last['duration'] + 3) {
            $newEnd = max($last['start_time'] + $last['duration'], $curr['start_time'] + $curr['duration']);
            // ★ Prefer URL-pattern start time (more precise for actual ad content)
            $preferStart = (strpos($curr['source'] ?? '', 'parsed') !== false && strpos($last['source'] ?? '', 'parsed') === false)
                ? $curr['start_time'] : $last['start_time'];
            $merged[count($merged)-1] = [
                'start_time' => $preferStart,
                'duration' => (int)round($newEnd - $preferStart),
                'confidence' => max($last['confidence'], $curr['confidence']),
                'source' => $last['source'] . '+' . $curr['source']
            ];
        } else {
            $merged[] = $curr;
        }
    }
    $ads = $merged;
}

// ============ LAYER 3: Store results in DB ============
if (count($ads) > 0) {
    $stmt = $db->prepare("INSERT INTO ad_markers (movie_id, server_name, m3u8_hash, start_time, duration, confidence, report_count) VALUES (?, ?, ?, ?, ?, ?, 1) ON DUPLICATE KEY UPDATE report_count = report_count + 1, confidence = LEAST(1, confidence + 0.1)");

    foreach ($ads as $ad) {
        $stmt->execute([$movie_id, $server_name, $m3u8_hash, $ad['start_time'], $ad['duration'], $ad['confidence']]);
    }
}

echo json_encode([
    'success' => true,
    'ads' => $ads,
    'total_duration' => (int)round($cumulative),
    'url' => $url,
    'layer' => 2,
    'message' => 'Parsed and stored in database'
]);
