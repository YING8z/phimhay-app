<?php
/**
 * API: Quản lý Hero Slides (thêm / xóa / sắp xếp / sửa)
 * Method: POST  { action: add|remove|reorder|replace, ... }
 *         GET   { action: list }
 */
define('INCLUDED', true);
require_once dirname(__DIR__) . '/includes/config.php';

header('Content-Type: application/json; charset=utf-8');

if (!isLoggedIn() || !isAdmin()) {
    http_response_code(403);
    echo json_encode(['success' => false, 'error' => 'Unauthorized'], JSON_UNESCAPED_UNICODE);
    exit;
}

$JSON_FILE = ROOT_PATH . '/data/hero_slides.json';
$db = getDB();

/* ---------- helpers ---------- */
function loadSlides(string $file): array {
    if (!is_file($file)) return [];
    $raw = file_get_contents($file);
    $data = json_decode($raw, true);
    return $data['slides'] ?? [];
}

function saveSlides(string $file, array $slides): bool {
    $json = json_encode(['slides' => array_values($slides)], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    $ok = file_put_contents($file, $json, LOCK_EX) !== false;
    // Invalidate homepage HTML cache so slider changes show immediately
    if ($ok && defined('ROOT_PATH')) {
        $cacheDir = ROOT_PATH . '/data/cache';
        if (is_dir($cacheDir)) {
            foreach (glob($cacheDir . '/home_*.html.gz') ?: [] as $f) {
                @unlink($f);
            }
        }
    }
    return $ok;
}

function movieInfoBySlug(string $slug): ?array {
    try {
        $db = getDB();
        $stmt = $db->prepare('SELECT id, slug, name, origin_name, poster_url, thumb_url, year, type, episode_current FROM movies WHERE slug = ? LIMIT 1');
        $stmt->execute([$slug]);
        $row = $stmt->fetch();
        if (!$row) return null;
        // Build local-first image URL (same logic as getMoviePoster)
        $thumbUrl = trim($row['thumb_url'] ?? '');
        $posterUrl = trim($row['poster_url'] ?? '');
        if ($thumbUrl !== '' && function_exists('phimhayResponsiveImageUrl')) {
            $row['local_image'] = phimhayResponsiveImageUrl($thumbUrl, 0, 'thumb', $row['slug'], (int)$row['id']);
        } elseif ($posterUrl !== '' && function_exists('phimhayResponsiveImageUrl')) {
            $row['local_image'] = phimhayResponsiveImageUrl($posterUrl, 0, 'poster', $row['slug'], (int)$row['id']);
        } else {
            $row['local_image'] = '';
        }
        return $row;
    } catch (Exception $e) {
        return null;
    }
}

/* ---------- routing ---------- */
$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? $_POST['action'] ?? '';

try {
    // ---- GET: list ----
    if ($method === 'GET' && $action === 'list') {
        $slides = loadSlides($JSON_FILE);
        $result = [];
        foreach ($slides as $s) {
            $movie = movieInfoBySlug($s['movie_slug'] ?? '');
            $result[] = [
                'movie_slug' => $s['movie_slug'] ?? '',
                'added_at'   => $s['added_at'] ?? '',
                'movie'      => $movie,
            ];
        }
        echo json_encode(['success' => true, 'slides' => $result], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    // ---- POST actions ----
    if ($method !== 'POST') {
        http_response_code(405);
        echo json_encode(['success' => false, 'error' => 'Method not allowed'], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $input = json_decode(file_get_contents('php://input'), true) ?: $_POST;
    $action = $input['action'] ?? '';

    $slides = loadSlides($JSON_FILE);

    switch ($action) {

        /* ---- ADD ---- */
        case 'add':
            $slug = trim((string)($input['movie_slug'] ?? ''));
            if ($slug === '') {
                echo json_encode(['success' => false, 'error' => 'Thiếu movie_slug'], JSON_UNESCAPED_UNICODE);
                exit;
            }
            // Check movie exists
            $movie = movieInfoBySlug($slug);
            if (!$movie) {
                echo json_encode(['success' => false, 'error' => 'Không tìm thấy phim: ' . $slug], JSON_UNESCAPED_UNICODE);
                exit;
            }
            // Check duplicate
            foreach ($slides as $s) {
                if (($s['movie_slug'] ?? '') === $slug) {
                    echo json_encode(['success' => false, 'error' => 'Phim này đã có trong slider'], JSON_UNESCAPED_UNICODE);
                    exit;
                }
            }
            $slides[] = [
                'movie_slug' => $slug,
                'added_at'   => date('Y-m-d H:i:s'),
            ];
            saveSlides($JSON_FILE, $slides);
            echo json_encode(['success' => true, 'movie' => $movie], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            exit;

        /* ---- REMOVE ---- */
        case 'remove':
            $slug = trim((string)($input['movie_slug'] ?? ''));
            $slides = array_values(array_filter($slides, fn($s) => ($s['movie_slug'] ?? '') !== $slug));
            saveSlides($JSON_FILE, $slides);
            echo json_encode(['success' => true], JSON_UNESCAPED_UNICODE);
            exit;

        /* ---- REPLACE (edit slug) ---- */
        case 'replace':
            $oldSlug = trim((string)($input['old_slug'] ?? ''));
            $newSlug = trim((string)($input['new_slug'] ?? ''));
            if ($oldSlug === '' || $newSlug === '') {
                echo json_encode(['success' => false, 'error' => 'Thiếu old_slug hoặc new_slug'], JSON_UNESCAPED_UNICODE);
                exit;
            }
            $movie = movieInfoBySlug($newSlug);
            if (!$movie) {
                echo json_encode(['success' => false, 'error' => 'Không tìm thấy phim: ' . $newSlug], JSON_UNESCAPED_UNICODE);
                exit;
            }
            foreach ($slides as &$s) {
                if (($s['movie_slug'] ?? '') === $oldSlug) {
                    $s['movie_slug'] = $newSlug;
                    break;
                }
            }
            unset($s);
            saveSlides($JSON_FILE, $slides);
            echo json_encode(['success' => true, 'movie' => $movie], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            exit;

        /* ---- REORDER ---- */
        case 'reorder':
            $order = $input['order'] ?? []; // array of slugs in new order
            if (!is_array($order) || empty($order)) {
                echo json_encode(['success' => false, 'error' => 'Thiếu order'], JSON_UNESCAPED_UNICODE);
                exit;
            }
            $map = [];
            foreach ($slides as $s) {
                $map[$s['movie_slug']] = $s;
            }
            $newSlides = [];
            foreach ($order as $slug) {
                if (isset($map[$slug])) {
                    $newSlides[] = $map[$slug];
                }
            }
            saveSlides($JSON_FILE, $newSlides);
            echo json_encode(['success' => true], JSON_UNESCAPED_UNICODE);
            exit;

        default:
            echo json_encode(['success' => false, 'error' => 'Unknown action: ' . $action], JSON_UNESCAPED_UNICODE);
            exit;
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()], JSON_UNESCAPED_UNICODE);
}
