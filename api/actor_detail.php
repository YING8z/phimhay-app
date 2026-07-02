<?php
require_once dirname(__DIR__) . '/includes/config.php';
header('Content-Type: application/json; charset=utf-8');

$name = trim($_GET['name'] ?? '');
$tmdbId = (int)($_GET['tmdb_id'] ?? 0);
if (!$name && !$tmdbId) { echo json_encode(['success' => false, 'message' => 'Thieu thong tin']); exit; }

$db = getDB();

function adActorSlug(string $name): string {
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

function adTmdbGet(string $path, array $extra = []) {
    $resolve = defined('TMDB_RESOLVE') && TMDB_RESOLVE ? ['api.themoviedb.org:443:' . TMDB_RESOLVE] : [];
    $url = TMDB_BASE . $path . (str_contains($path, '?') ? '&' : '?') . 'api_key=' . TMDB_API_KEY;
    foreach ($extra as $k => $v) { $url .= '&' . $k . '=' . urlencode($v); }
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 8, CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_USERAGENT => 'PhimHay/1.0 (actor-detail)', CURLOPT_RESOLVE => $resolve,
    ]);
    $res = curl_exec($ch); curl_close($ch);
    return $res ? json_decode($res, true) : null;
}

// ═══════════════════════════════════════════════════
// STEP 1: Find actor (copy from dien-vien.php)
// ═══════════════════════════════════════════════════
$row = null;
if ($tmdbId > 0) {
    $stmt = $db->prepare("SELECT * FROM actors WHERE tmdb_id = ? LIMIT 1");
    $stmt->execute([$tmdbId]);
    $row = $stmt->fetch();
}
if (!$row && $name) {
    $stmt = $db->prepare("SELECT * FROM actors WHERE name = ? LIMIT 1");
    $stmt->execute([$name]);
    $row = $stmt->fetch();
}
if (!$row && $name) {
    $stmt = $db->prepare("SELECT * FROM actors WHERE name_vi = ? LIMIT 1");
    $stmt->execute([$name]);
    $row = $stmt->fetch();
}
if (!$row && $name) {
    $slug = adActorSlug($name);
    $stmt = $db->prepare("SELECT * FROM actors WHERE slug = ? LIMIT 1");
    $stmt->execute([$slug]);
    $row = $stmt->fetch();
}
if (!$row && $name) {
    $stmt = $db->prepare('SELECT * FROM actors WHERE also_known_as LIKE ? LIMIT 1');
    $stmt->execute(['%"' . $name . '"%']);
    $row = $stmt->fetch();
}

$actorName = $name;
$actorNameVi = '';
$actorPhoto = '';
$actorGender = '';
$actorBirthday = '';
$actorDeathday = '';
$actorBio = '';
$actorPlace = '';
$actorAlsoKnown = [];
$movies = [];
$wikiMovies = null;
$fetchedId = $tmdbId;

if ($row) {
    $actorName = $row['name'];
    $actorNameVi = $row['name_vi'] ?? '';
    $actorPhoto = $row['photo_url'] ?? null;
    $actorGender = match((int)($row['gender'] ?? 0)) { 1 => 'Nữ', 2 => 'Nam', default => 'Khác' };
    $actorBirthday = $row['birthday'] ?? null;
    $actorDeathday = $row['deathday'] ?? null;
    $actorBio = $row['biography'] ?? '';
    $actorPlace = $row['place_of_birth'] ?? '';
    $actorAlsoKnown = json_decode($row['also_known_as'] ?? '[]', true);
    $movies = json_decode($row['movies_json'] ?? '[]', true) ?: [];
    $wikiMovies = json_decode($row['wiki_movies'] ?? 'null', true);
    $fetchedId = (int)$row['tmdb_id'];
    // Extract Chinese name from also_known
    foreach ($actorAlsoKnown as $ak) {
        if (preg_match('/[\x{4e00}-\x{9fff}]/u', $ak)) { $actorNameVi = $ak; break; }
    }
}

// Fetch from TMDB if not found
if (empty($movies)) {
    if (!$fetchedId && $name) {
        foreach (['vi-VN', 'en-US', 'zh-CN'] as $lang) {
            $s = adTmdbGet('/search/person', ['query' => $name, 'include_adult' => 'false', 'language' => $lang]);
            if (!empty($s['results'])) { $fetchedId = (int)$s['results'][0]['id']; break; }
        }
    }
    if ($fetchedId) {
        $person = adTmdbGet("/person/{$fetchedId}");
        if ($person && !isset($person['success'])) {
            $actorName = $person['name'] ?? $name;
            $actorAlsoKnown = $person['also_known_as'] ?? [];
            $actorGender = match((int)($person['gender'] ?? 0)) { 1 => 'Nữ', 2 => 'Nam', default => 'Khác' };
            $actorBirthday = $person['birthday'] ?? null;
            $actorDeathday = $person['deathday'] ?? null;
            $actorBio = $person['biography'] ?? '';
            $actorPlace = $person['place_of_birth'] ?? '';
            $actorPhoto = !empty($person['profile_path']) ? 'https://image.tmdb.org/t/p/w500' . $person['profile_path'] : null;

            foreach ($actorAlsoKnown as $ak) {
                if (preg_match('/[\x{4e00}-\x{9fff}]/u', $ak)) { $actorNameVi = $ak; break; }
            }

            $credits = adTmdbGet("/person/{$fetchedId}/movie_credits");
            if (!empty($credits['cast'])) {
                foreach ($credits['cast'] as $c) {
                    $movies[] = [
                        'id' => $c['id'], 'title' => $c['title'] ?? '', 'original' => $c['original_title'] ?? '',
                        'character' => $c['character'] ?? '',
                        'poster' => !empty($c['poster_path']) ? 'https://image.tmdb.org/t/p/w500' . $c['poster_path'] : null,
                        'year' => !empty($c['release_date']) ? substr($c['release_date'], 0, 4) : null,
                        'rating' => $c['vote_average'] ?? 0,
                    ];
                }
                usort($movies, fn($a, $b) => ($b['rating'] ?? 0) <=> ($a['rating'] ?? 0));
            }

            // Save to DB
            $actorSlug = adActorSlug($actorNameVi ?: $actorName);
            if ($row) {
                $db->prepare("UPDATE actors SET name_vi=COALESCE(name_vi,?),tmdb_id=?,photo_url=?,biography=?,birthday=?,deathday=?,gender=?,place_of_birth=?,also_known_as=?,movies_json=?,last_synced=NOW() WHERE slug=?")
                   ->execute([$actorNameVi ?: $actorName, $fetchedId, $actorPhoto, $actorBio, $actorBirthday, $actorDeathday, $actorGender, $actorPlace, json_encode($actorAlsoKnown, JSON_UNESCAPED_UNICODE), json_encode(array_slice($movies, 0, 50), JSON_UNESCAPED_UNICODE), $actorSlug]);
            } else {
                $db->prepare("INSERT INTO actors (name,name_vi,slug,tmdb_id,photo_url,biography,birthday,deathday,gender,place_of_birth,also_known_as,movies_json,last_synced) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,NOW())")
                   ->execute([$actorName, $actorNameVi, $actorSlug, $fetchedId, $actorPhoto, $actorBio, $actorBirthday, $actorDeathday, $actorGender, $actorPlace, json_encode($actorAlsoKnown, JSON_UNESCAPED_UNICODE), json_encode(array_slice($movies, 0, 50), JSON_UNESCAPED_UNICODE)]);
            }
        }
    }
}

if (empty($movies) && !$actorPhoto) {
    echo json_encode(['success' => false, 'message' => 'Khong tim thay dien vien']);
    exit;
}

// ═══════════════════════════════════════════════════
// STEP 2: Merge with DB (COPY GIONG dien-vien.php 100%)
// ═══════════════════════════════════════════════════

$moviesBySlug = [];
$searchKeys = [];
$tmdbIds = [];
foreach ($movies as $idx => &$mv) {
    $mvSlug = slug($mv['title'] ?: $mv['original'] ?? '');
    if ($mvSlug) $moviesBySlug[$mvSlug] = $idx;
    $orig = trim($mv['original'] ?? '');
    if ($orig !== '') $searchKeys[strtolower($orig)] = $idx;
    $title = trim($mv['title'] ?? '');
    if ($title !== '' && $title !== $orig) $searchKeys[strtolower($title)] = $idx;
    $tid = (int)($mv['id'] ?? 0);
    if ($tid > 0) $tmdbIds[$tid] = $idx;
}
unset($mv);

$setDbData = function(&$movies, int $idx, array $sqlRow) {
    $movies[$idx]['_in_db'] = true;
    $movies[$idx]['db_slug'] = $sqlRow['slug'];
    $movies[$idx]['db_name'] = $sqlRow['name'] ?: $movies[$idx]['title'];
    $movies[$idx]['db_origin'] = $sqlRow['origin_name'] ?: $movies[$idx]['original'];
    $movies[$idx]['db_thumb'] = $sqlRow['thumb_url'] ?: '';
    $movies[$idx]['db_poster_url'] = $sqlRow['poster_url'] ?: '';
    $movies[$idx]['db_quality'] = $sqlRow['quality'] ?? '';
    $movies[$idx]['db_lang'] = $sqlRow['lang'] ?? '';
    $movies[$idx]['db_ep_cur'] = $sqlRow['episode_current'] ?? '';
    $movies[$idx]['db_ep_total'] = $sqlRow['episode_total'] ?? '';
    $movies[$idx]['db_type'] = $sqlRow['type'] ?? '';
    $movies[$idx]['db_year'] = $sqlRow['year'] ?? $movies[$idx]['year'] ?? '';
    $movies[$idx]['db_view'] = (int)($sqlRow['view_count'] ?? 0);
    $movies[$idx]['db_imdb'] = (float)($sqlRow['imdb_rating'] ?? 0);
    $movies[$idx]['db_tmdb_rating'] = (float)($sqlRow['tmdb_rating'] ?? 0);
};

$cols = 'slug, name, origin_name, thumb_url, poster_url, year, quality, lang, episode_current, episode_total, type, view_count, imdb_rating, tmdb_rating, tmdb_id, actor, imdb_cast';

// Query 1: Match theo slug
if (!empty($moviesBySlug)) {
    $slugs = array_keys($moviesBySlug);
    $ph = implode(',', array_fill(0, count($slugs), '?'));
    $sqlStmt = $db->prepare("SELECT {$cols} FROM movies WHERE slug IN ({$ph})");
    $sqlStmt->execute($slugs);
    while ($sqlRow = $sqlStmt->fetch()) {
        if (isset($moviesBySlug[$sqlRow['slug']])) {
            $idx = $moviesBySlug[$sqlRow['slug']];
            if (empty($movies[$idx]['_in_db'])) $setDbData($movies, $idx, $sqlRow);
        }
    }
}

// Query 2: Match theo origin_name VA name
if (!empty($searchKeys)) {
    $sKeys = array_keys($searchKeys);
    $ph = implode(',', array_fill(0, count($sKeys), '?'));
    $sqlStmt2 = $db->prepare("SELECT {$cols} FROM movies WHERE LOWER(origin_name) IN ({$ph}) OR LOWER(name) IN ({$ph})");
    $sqlStmt2->execute(array_merge($sKeys, $sKeys));
    while ($sqlRow = $sqlStmt2->fetch()) {
        $on = strtolower($sqlRow['origin_name']);
        $nn = strtolower($sqlRow['name']);
        $idx = $searchKeys[$on] ?? $searchKeys[$nn] ?? null;
        if ($idx !== null && empty($movies[$idx]['_in_db'])) {
            $setDbData($movies, $idx, $sqlRow);
        }
    }
}

// Query 3: Match theo tmdb_id
if (!empty($tmdbIds)) {
    $ids = array_keys($tmdbIds);
    $ph = implode(',', array_fill(0, count($ids), '?'));
    $sqlStmt3 = $db->prepare("SELECT {$cols} FROM movies WHERE tmdb_id IN ({$ph})");
    $sqlStmt3->execute($ids);
    while ($sqlRow = $sqlStmt3->fetch()) {
        $tid = (int)$sqlRow['tmdb_id'];
        if (isset($tmdbIds[$tid])) {
            $idx = $tmdbIds[$tid];
            if (empty($movies[$idx]['_in_db'])) $setDbData($movies, $idx, $sqlRow);
        }
    }
}

// Query 4: Tim phim theo ten dien vien trong DB — chi khi chua sync Wiki
if (empty($wikiMovies)) {
$actorSearchNames = array_filter(array_unique(array_merge(
    [$actorName],
    $actorAlsoKnown,
    [$actorNameVi],
)));
if (!empty($actorSearchNames)) {
    $likeClauses = [];
    $likeParams = [];
    foreach ($actorSearchNames as $an) {
        $an = trim((string) $an);
        if ($an === '') continue;
        $likeClauses[] = 'actor LIKE ?';
        $likeParams[] = '%' . $an . '%';
        $likeClauses[] = 'imdb_cast LIKE ?';
        $likeParams[] = '%' . $an . '%';
    }
    if (!empty($likeClauses)) {
        $whereSql4 = implode(' OR ', $likeClauses);
        $sqlStmt4 = $db->prepare("SELECT {$cols} FROM movies WHERE ($whereSql4) ORDER BY view_count DESC LIMIT 100");
        $sqlStmt4->execute($likeParams);

        $existingSlugs = array_column(array_filter($movies, fn($m) => !empty($m['_in_db'])), 'db_slug');
        $existingSlugs = array_filter($existingSlugs);
        $existingTmdbIds = [];
        foreach ($movies as $mv) {
            $tid = (int)($mv['id'] ?? 0);
            if ($tid > 0) $existingTmdbIds[$tid] = true;
        }
        $existingOrigins = [];
        foreach ($movies as $mv) {
            $orig = strtolower(trim($mv['original'] ?? ''));
            if ($orig !== '') $existingOrigins[$orig] = true;
            $tit = strtolower(trim($mv['title'] ?? ''));
            if ($tit !== '' && $tit !== $orig) $existingOrigins[$tit] = true;
        }

        while ($sqlRow4 = $sqlStmt4->fetch()) {
            $isDupe = false;
            if (in_array($sqlRow4['slug'], $existingSlugs, true)) $isDupe = true;
            if (!$isDupe) {
                $tid4 = (int)($sqlRow4['tmdb_id'] ?? 0);
                if ($tid4 > 0 && isset($existingTmdbIds[$tid4])) $isDupe = true;
            }
            if (!$isDupe) {
                $on4 = strtolower($sqlRow4['origin_name'] ?? '');
                $nn4 = strtolower($sqlRow4['name'] ?? '');
                if (isset($existingOrigins[$on4]) || isset($existingOrigins[$nn4])) $isDupe = true;
            }
            if ($isDupe) continue;

            $movies[] = [
                'id'          => (int)($sqlRow4['tmdb_id'] ?? 0),
                'title'       => $sqlRow4['name'] ?? '',
                'original'    => $sqlRow4['origin_name'] ?? '',
                'character'   => '',
                'poster'      => $sqlRow4['poster_url'] ?: $sqlRow4['thumb_url'] ?? '',
                'year'        => $sqlRow4['year'] ?? '',
                'rating'      => (float)($sqlRow4['imdb_rating'] ?? 0),
                '_in_db'      => true,
                'db_slug'     => $sqlRow4['slug'],
                'db_name'     => $sqlRow4['name'],
                'db_origin'   => $sqlRow4['origin_name'],
                'db_thumb'    => $sqlRow4['thumb_url'] ?? '',
                'db_poster_url' => $sqlRow4['poster_url'] ?? '',
                'db_quality'  => $sqlRow4['quality'] ?? '',
                'db_lang'     => $sqlRow4['lang'] ?? '',
                'db_ep_cur'   => $sqlRow4['episode_current'] ?? '',
                'db_ep_total' => $sqlRow4['episode_total'] ?? '',
                'db_type'     => $sqlRow4['type'] ?? '',
                'db_year'     => $sqlRow4['year'] ?? '',
                'db_view'     => (int)($sqlRow4['view_count'] ?? 0),
                'db_imdb'     => (float)($sqlRow4['imdb_rating'] ?? 0),
            ];
        }
    }
}
} // end Query 4 (chi chua sync Wiki)

// ═══════════════════════════════════════════════════
// Loc phim theo Wiki: neu actor da sync Wiki, chi giu phim co trong danh sach Wiki
// ═══════════════════════════════════════════════════
if (!empty($wikiMovies) && is_array($wikiMovies)) {
    function adNorm(string $s): string {
        $s = mb_strtolower(trim($s), 'UTF-8');
        $from = ['à','á','ả','ã','ạ','ă','ắ','ặ','ằ','ẳ','ẵ','â','ấ','ầ','ẩ','ẫ','ậ',
                 'đ','è','é','ẻ','ẽ','ẹ','ê','ế','ề','ể','ễ','ệ',
                 'ì','í','ỉ','ĩ','ị','ò','ó','ỏ','õ','ọ','ô','ố','ồ','ổ','ỗ','ộ',
                 'ơ','ớ','ờ','ở','ỡ','ợ','ù','ú','ủ','ũ','ụ','ư','ứ','ừ','ử','ữ','ự',
                 'ỳ','ý','ỷ','ỹ','ỵ'];
        $to   = ['a','a','a','a','a','a','a','a','a','a','a','a','a','a','a','a','a',
                 'd','e','e','e','e','e','e','e','e','e','e','e',
                 'i','i','i','i','i','o','o','o','o','o','o','o','o','o','o','o',
                 'o','o','o','o','o','o','u','u','u','u','u','u','u','u','u','u','u',
                 'y','y','y','y','y'];
        $s = str_replace($from, $to, $s);
        $s = preg_replace('/\b\d{4}\b/', '', $s);
        $s = preg_replace('/[^\p{L}\p{N}\s]/u', ' ', $s);
        return preg_replace('/\s+/', ' ', trim($s));
    }

    $wikiKeys = [];
    foreach ($wikiMovies as $wm) {
        $wk = adNorm((string) $wm);
        if ($wk !== '' && mb_strlen($wk) >= 2) $wikiKeys[$wk] = true;
    }
    $movies = array_values(array_filter($movies, function($m) use ($wikiKeys) {
        $orig = adNorm($m['original'] ?? $m['db_origin'] ?? '');
        $tit  = adNorm($m['title'] ?? $m['db_name'] ?? '');
        if (($orig !== '' && isset($wikiKeys[$orig])) || ($tit !== '' && isset($wikiKeys[$tit]))) return true;
        foreach ($wikiKeys as $wk => $_) {
            if ($orig !== '' && $orig === $wk) return true;
            if ($tit !== '' && $tit === $wk) return true;
        }
        return false;
    }));
}

// ═══════════════════════════════════════════════════
// Batch-fetch the loai cho cac phim co trong SQL
// ═══════════════════════════════════════════════════
$genreMap = [];
$movieIdsForGenre = [];
foreach ($movies as $mv) {
    if (!empty($mv['_in_db']) && !empty($mv['db_slug'])) {
        $sId = $db->prepare("SELECT id FROM movies WHERE slug=?");
        $sId->execute([$mv['db_slug']]);
        $rId = $sId->fetch();
        if ($rId) $movieIdsForGenre[] = (int)$rId['id'];
    }
}
if (!empty($movieIdsForGenre)) {
    $ph = implode(',', array_fill(0, count($movieIdsForGenre), '?'));
    $sG = $db->prepare("SELECT mg.movie_id, g.name FROM movie_genres mg JOIN genres g ON g.id=mg.genre_id WHERE mg.movie_id IN ($ph)");
    $sG->execute($movieIdsForGenre);
    while ($rg = $sG->fetch()) {
        $genreMap[(int)$rg['movie_id']][] = $rg['name'];
    }
}

// ═══════════════════════════════════════════════════
// Output JSON
// ═══════════════════════════════════════════════════
$actor = [
    'name'       => $actorName,
    'name_vi'    => $actorNameVi,
    'tmdb_id'    => $fetchedId,
    'photo'      => $actorPhoto,
    'gender'     => $actorGender,
    'birthday'   => $actorBirthday,
    'deathday'   => $actorDeathday,
    'biography'  => $actorBio,
    'place'      => $actorPlace,
    'also_known' => $actorAlsoKnown,
];

// Attach genres to each movie
foreach ($movies as &$mv) {
    $mvId = 0;
    if (!empty($mv['_in_db']) && !empty($mv['db_slug'])) {
        $sId = $db->prepare("SELECT id FROM movies WHERE slug=?");
        $sId->execute([$mv['db_slug']]);
        $rId = $sId->fetch();
        if ($rId) $mvId = (int)$rId['id'];
    }
    $mv['genres'] = $genreMap[$mvId] ?? [];
}
unset($mv);

echo json_encode(['success' => true, 'actor' => $actor, 'movies' => $movies]);
