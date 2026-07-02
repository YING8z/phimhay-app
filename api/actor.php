<?php
require_once dirname(__DIR__) . '/includes/config.php';
header('Content-Type: application/json; charset=utf-8');

$names = [];
$singleName = trim($_GET['name'] ?? '');
$tmdbId = (int)($_GET['tmdb_id'] ?? 0);
$batchMode = !empty($_GET['batch']);
$forceSync = !empty($_GET['sync']);
$listMode = !empty($_GET['list']);

if ($listMode) {
    $db = getDB();
    $page = max(1, (int)($_GET['page'] ?? 1));
    $perPage = min(100, max(1, (int)($_GET['per_page'] ?? 50)));
    $offset = ($page - 1) * $perPage;
    $search = trim($_GET['q'] ?? '');

    if ($search) {
        $like = "%{$search}%";
        $countStmt = $db->prepare("SELECT COUNT(*) as c FROM actors WHERE name_vi LIKE ? OR name LIKE ?");
        $countStmt->execute([$like, $like]);
        $total = $countStmt->fetch()['c'];

        $stmt = $db->prepare("SELECT name, name_vi, photo_url, tmdb_id, gender, birthday, slug FROM actors WHERE name_vi LIKE ? OR name LIKE ? ORDER BY name_vi ASC LIMIT ? OFFSET ?");
        $stmt->execute([$like, $like, $perPage, $offset]);
    } else {
        $countStmt = $db->query("SELECT COUNT(*) as c FROM actors");
        $total = $countStmt->fetch()['c'];

        $stmt = $db->prepare("SELECT name, name_vi, photo_url, tmdb_id, gender, birthday, slug FROM actors ORDER BY name_vi ASC LIMIT ? OFFSET ?");
        $stmt->execute([$perPage, $offset]);
    }

    $actors = [];
    while ($r = $stmt->fetch()) {
        $actors[] = [
            'name' => $r['name'],
            'name_vi' => $r['name_vi'],
            'photo_url' => $r['photo_url'],
            'tmdb_id' => (int)$r['tmdb_id'],
            'gender' => $r['gender'] ?? '',
            'birthday' => $r['birthday'] ?? null,
            'slug' => $r['slug'] ?? '',
        ];
    }
    echo json_encode(['success' => true, 'actors' => $actors, 'total' => $total, 'page' => $page, 'per_page' => $perPage]);
    exit;
}

if ($batchMode) {
    $raw = $_GET['names'] ?? '';
    foreach (explode(',', $raw) as $n) {
        $n = trim($n);
        if ($n !== '') $names[] = $n;
    }
    if (empty($names)) { echo json_encode(['success' => false]); exit; }
} elseif ($singleName) {
    $names[] = $singleName;
} else {
    echo json_encode(['success' => false, 'message' => 'Thiếu tên']); exit;
}

$db = getDB();

$resolve = defined('TMDB_RESOLVE') && TMDB_RESOLVE ? ['api.themoviedb.org:443:' . TMDB_RESOLVE] : [];

function tmdbGet(string $path, array $extra = []) {
    global $resolve;
    $url = TMDB_BASE . $path . (str_contains($path, '?') ? '&' : '?') . 'api_key=' . TMDB_API_KEY;
    foreach ($extra as $k => $v) { $url .= '&' . $k . '=' . urlencode($v); }
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 8, CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_USERAGENT => 'PhimHay/1.0 (actor)',
        CURLOPT_RESOLVE => $resolve,
    ]);
    $res = curl_exec($ch);
    curl_close($ch);
    return $res ? json_decode($res, true) : null;
}

function actorSlug(string $name): string {
    $s = mb_strtolower(trim($name), 'UTF-8');
    $s = preg_replace('/[àáạảãâầấậẩẫăằắặẳẵ]/u', 'a', $s);
    $s = preg_replace('/[èéẹẻẽêềếệểễ]/u', 'e', $s);
    $s = preg_replace('/[ìíịỉĩ]/u', 'i', $s);
    $s = preg_replace('/[òóọỏõôồốộổỗơờớợởỡ]/u', 'o', $s);
    $s = preg_replace('/[ùúụủũưừứựửữ]/u', 'u', $s);
    $s = preg_replace('/[ỳýỵỷỹ]/u', 'y', $s);
    $s = preg_replace('/đ/u', 'd', $s);
    if (preg_match('/[\x{4e00}-\x{9fff}]/u', $s)) {
        $s = preg_replace('/[^a-z0-9\x{4e00}-\x{9fff}\s-]/u', '', $s);
    } else {
        $s = preg_replace('/[^a-z0-9\s-]/', '', $s);
    }
    $s = preg_replace('/[\s-]+/', '-', $s);
    return trim($s, '-') ?: bin2hex(random_bytes(4));
}

function searchTMDBPerson(string $name): ?int {
    $search = tmdbGet('/search/person', ['query' => $name, 'include_adult' => 'false', 'language' => 'vi-VN']);
    if (!empty($search['results'])) {
        foreach ($search['results'] as $r) {
            if (mb_strtolower($r['name'] ?? '') === mb_strtolower($name)) return (int)$r['id'];
        }
        return (int)$search['results'][0]['id'];
    }
    $search2 = tmdbGet('/search/person', ['query' => $name, 'include_adult' => 'false', 'language' => 'en-US']);
    if (!empty($search2['results'])) {
        foreach ($search2['results'] as $r) {
            if (mb_strtolower($r['name'] ?? '') === mb_strtolower($name)) return (int)$r['id'];
        }
        return (int)$search2['results'][0]['id'];
    }
    $search3 = tmdbGet('/search/person', ['query' => $name, 'include_adult' => 'false', 'language' => 'zh-CN']);
    if (!empty($search3['results'])) {
        return (int)$search3['results'][0]['id'];
    }
    return null;
}

function fetchAndCacheActor($db, string $name, int $tmdbId = 0): ?array {
    global $forceSync;
    $slug = actorSlug($name);

    $existing = $db->prepare("SELECT * FROM actors WHERE slug = ? OR name = ? OR name_vi = ? OR JSON_SEARCH(also_known_as, 'one', ?) IS NOT NULL LIMIT 1");
    $existing->execute([$slug, $name, $name, $name]);
    $row = $existing->fetch();

    if ($row && !$tmdbId && !$forceSync) {
        $synced = strtotime($row['last_synced'] ?? '2000-01-01');
        if ((time() - $synced) < 30 * 86400) {
            return [
                'tmdb_id'    => (int)$row['tmdb_id'],
                'name'       => $row['name'],
                'also_known' => json_decode($row['also_known_as'] ?? '[]', true),
                'gender'     => $row['gender'] ?? '',
                'birthday'   => $row['birthday'] ?? null,
                'deathday'   => $row['deathday'] ?? null,
                'biography'  => $row['biography'] ?? '',
                'photo'      => $row['photo_url'] ?? null,
                'place'      => $row['place_of_birth'] ?? '',
                'movies'     => json_decode($row['movies_json'] ?? '[]', true),
            ];
        }
    }

    if (!$tmdbId) $tmdbId = searchTMDBPerson($name);
    if (!$tmdbId) return null;

    $person = tmdbGet("/person/{$tmdbId}");
    if (!$person || isset($person['success'])) return null;

    $credits = tmdbGet("/person/{$tmdbId}/movie_credits");
    $movies = [];
    if (!empty($credits['cast'])) {
        foreach ($credits['cast'] as $c) {
            $movies[] = [
                'id'        => $c['id'],
                'title'     => $c['title'] ?? '',
                'original'  => $c['original_title'] ?? '',
                'character' => $c['character'] ?? '',
                'poster'    => !empty($c['poster_path']) ? 'https://image.tmdb.org/t/p/w500' . $c['poster_path'] : null,
                'year'      => !empty($c['release_date']) ? substr($c['release_date'], 0, 4) : null,
                'rating'    => $c['vote_average'] ?? 0,
            ];
        }
        usort($movies, fn($a, $b) => ($b['rating'] ?? 0) <=> ($a['rating'] ?? 0));
    }

    $gender = match((int)($person['gender'] ?? 0)) { 1 => 'Nữ', 2 => 'Nam', default => 'Khác' };
    $alsoKnown = $person['also_known_as'] ?? [];
    $photo = !empty($person['profile_path']) ? 'https://image.tmdb.org/t/p/w500' . $person['profile_path'] : null;

    if ($row) {
        $db->prepare("UPDATE actors SET name_vi=COALESCE(name_vi,?), tmdb_id=?, photo_url=?, biography=?, birthday=?, deathday=?, gender=?, place_of_birth=?, also_known_as=?, movies_json=?, last_synced=NOW() WHERE slug=?")
           ->execute([$name, $tmdbId, $photo, $person['biography'] ?? '', $person['birthday'] ?? null, $person['deathday'] ?? null, $gender, $person['place_of_birth'] ?? '', json_encode($alsoKnown, JSON_UNESCAPED_UNICODE), json_encode(array_slice($movies, 0, 50), JSON_UNESCAPED_UNICODE), $slug]);
    } else {
        $db->prepare("INSERT INTO actors (name, name_vi, slug, tmdb_id, photo_url, biography, birthday, deathday, gender, place_of_birth, also_known_as, movies_json, last_synced) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,NOW())")
           ->execute([$person['name'] ?? $name, $name, $slug, $tmdbId, $photo, $person['biography'] ?? '', $person['birthday'] ?? null, $person['deathday'] ?? null, $gender, $person['place_of_birth'] ?? '', json_encode($alsoKnown, JSON_UNESCAPED_UNICODE), json_encode(array_slice($movies, 0, 50), JSON_UNESCAPED_UNICODE)]);
    }

    return [
        'tmdb_id'    => $tmdbId,
        'name'       => $person['name'] ?? $name,
        'also_known' => $alsoKnown,
        'gender'     => $gender,
        'birthday'   => $person['birthday'] ?? null,
        'deathday'   => $person['deathday'] ?? null,
        'biography'  => $person['biography'] ?? '',
        'photo'      => $photo,
        'place'      => $person['place_of_birth'] ?? '',
        'movies'     => array_slice($movies, 0, 50),
    ];
}

try {
    if ($batchMode) {
        if (empty($names)) { echo json_encode(['success' => true, 'actors' => []]); exit; }

        $placeholders = implode(',', array_fill(0, count($names), '?'));
        $stmt = $db->prepare("SELECT name, name_vi, photo_url, tmdb_id FROM actors WHERE name_vi IN ($placeholders) OR name IN ($placeholders)");
        $allParams = array_merge($names, $names);
        $stmt->execute($allParams);
        $cached = [];
        while ($r = $stmt->fetch()) { $cached[$r['name_vi']] = $r; }

        $missing = [];
        foreach ($names as $n) {
            if (!isset($cached[$n]) || !$cached[$n]['photo_url']) $missing[] = $n;
        }

        // Try to find missing actors by also_known_as
        if ($missing) {
            foreach ($missing as $n) {
                $stmt2 = $db->prepare("SELECT name, name_vi, photo_url, tmdb_id FROM actors WHERE JSON_SEARCH(also_known_as, 'one', ?) IS NOT NULL LIMIT 1");
                $stmt2->execute([$n]);
                $r2 = $stmt2->fetch();
                if ($r2 && $r2['photo_url']) { $cached[$n] = $r2; }
            }
        }

        // Background sync: fetch missing actors from TMDB (max 2 per batch to avoid slowdown)
        // Only sync if explicitly requested or if we have very few cached actors
        $shouldSync = !empty($_GET['sync_missing']) || count($cached) < 2;
        if ($shouldSync && $missing) {
            $syncLimit = 2; // Max 2 actors per request to keep it fast
            $synced = 0;
            foreach ($missing as $n) {
                if ($synced >= $syncLimit) break;
                if (isset($cached[$n]) && $cached[$n]['photo_url']) continue;

                $actorData = fetchAndCacheActor($db, $n);
                if ($actorData && $actorData['photo']) {
                    $cached[$n] = [
                        'name' => $actorData['name'],
                        'name_vi' => $n,
                        'photo_url' => $actorData['photo'],
                        'tmdb_id' => $actorData['tmdb_id']
                    ];
                    $synced++;
                }
            }
        }

        $results = [];
        foreach ($names as $n) {
            if (isset($cached[$n]) && $cached[$n]['photo_url']) {
                $results[] = ['input' => $n, 'name' => $cached[$n]['name'], 'photo' => $cached[$n]['photo_url'], 'tmdb_id' => (int)$cached[$n]['tmdb_id']];
            }
        }
        echo json_encode(['success' => true, 'actors' => $results]);
        exit;
    }

    $data = fetchAndCacheActor($db, $names[0], $tmdbId);
    if (!$data) {
        echo json_encode(['success' => false, 'message' => 'Không tìm thấy']);
        exit;
    }
    echo json_encode(['success' => true, 'actor' => $data, 'movies' => $data['movies'] ?? []]);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
