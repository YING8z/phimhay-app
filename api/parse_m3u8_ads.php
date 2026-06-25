<?php
/**
 * Parse m3u8 playlist → detect ad segments by URL pattern
 * Returns JSON array of ad markers with start_time and duration
 *
 * Usage: parse_m3u8_ads.php?url=https://example.com/video.m3u8
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$url = $_GET['url'] ?? '';
if (empty($url)) {
    echo json_encode(['error' => 'Missing url parameter', 'ads' => []]);
    exit;
}

function isAdSegment($segUrl) {
    $patterns = ['/v8/', '/v7/', '/adjump/', '/ad/', 'segment_0', 'ad_'];
    foreach ($patterns as $p) {
        if (stripos($segUrl, $p) !== false) return true;
    }
    return false;
}

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

// Fetch the m3u8 playlist
$content = fetchUrl($url);
if ($content === false) {
    echo json_encode(['error' => 'Failed to fetch m3u8', 'url' => $url, 'ads' => []]);
    exit;
}

// If master playlist → get variant
if (strpos($content, '#EXT-X-STREAM-INF') !== false) {
    $lines = explode("\n", trim($content));
    foreach ($lines as $line) {
        $line = trim($line);
        if (!empty($line) && $line[0] !== '#' && strpos($line, '.m3u8') !== false) {
            // Resolve relative URL properly
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
    echo json_encode(['error' => 'Empty playlist', 'url' => $url, 'ads' => []]);
    exit;
}

// Parse segments
$lines = explode("\n", trim($content));
$cumulative = 0.0;
$ads = [];
$adBlockStart = null;

for ($i = 0; $i < count($lines); $i++) {
    $line = trim($lines[$i]);
    if (strpos($line, '#EXTINF:') !== 0) continue;

    // Parse duration: #EXTINF:10.000,...
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
        $segUrl = rtrim(dirname($url), '/') . '/' . $segUrl;
    }

    $isAd = isAdSegment($segUrl);

    if ($isAd) {
        if ($adBlockStart === null) $adBlockStart = $cumulative;
    } else {
        if ($adBlockStart !== null) {
            $blockDur = $cumulative - $adBlockStart;
            if ($blockDur > 0) {
                $ads[] = [
                    'start_time' => (int)round($adBlockStart),
                    'duration'   => (int)round($blockDur),
                ];
            }
            $adBlockStart = null;
        }
    }

    $cumulative += $dur;
}

// Last ad block
if ($adBlockStart !== null) {
    $blockDur = $cumulative - $adBlockStart;
    if ($blockDur > 0) {
        $ads[] = [
            'start_time' => (int)round($adBlockStart),
            'duration'   => (int)round($blockDur),
        ];
    }
}

echo json_encode([
    'success' => true,
    'ads'     => $ads,
    'total_duration' => (int)round($cumulative),
    'url'     => $url,
]);
