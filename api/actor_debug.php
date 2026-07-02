<?php
require_once dirname(__DIR__) . '/includes/config.php';
header('Content-Type: application/json; charset=utf-8');

$db = getDB();
$tmdbId = 1476992;

// 1. Check movies_json
$stmt = $db->prepare("SELECT movies_json, wiki_movies FROM actors WHERE tmdb_id = ?");
$stmt->execute([$tmdbId]);
$row = $stmt->fetch();
$moviesJson = json_decode($row['movies_json'] ?? '[]', true) ?: [];
$wikiMovies = json_decode($row['wiki_movies'] ?? 'null', true);

$result = [
    'movies_json_count' => count($moviesJson),
    'wiki_movies' => $wikiMovies,
    'wiki_movies_count' => is_array($wikiMovies) ? count($wikiMovies) : 0,
    'movies_json_titles' => array_map(fn($m) => $m['title'] ?? '??', $moviesJson),
];

// 2. Search by all names
$actorName = 'Chen Duling';
$alsoKnown = json_decode($row['also_known_as'] ?? '[]', true) ?: ['陈都灵','Chen Du Ling','천두링','Trần Đô Linh','陳都靈','چن دودینگ'];
$actorNameVi = '陈都灵';

$allNames = array_filter(array_unique(array_merge([$actorName], $alsoKnown, [$actorNameVi])));

$likeClauses = [];
$likeParams = [];
foreach ($allNames as $an) {
    $an = trim((string)$an);
    if ($an === '') continue;
    $likeClauses[] = 'actor LIKE ?';
    $likeParams[] = '%' . $an . '%';
    $likeClauses[] = 'imdb_cast LIKE ?';
    $likeParams[] = '%' . $an . '%';
}
$whereSql = implode(' OR ', $likeClauses);
$s = $db->prepare("SELECT slug, name, origin_name, tmdb_id FROM movies WHERE ($whereSql) ORDER BY view_count DESC LIMIT 50");
$s->execute($likeParams);
$dbResults = $s->fetchAll();

$result['search_names'] = $allNames;
$result['query4_count'] = count($dbResults);
$result['query4_movies'] = array_map(fn($r) => ['name'=>$r['name'], 'origin'=>$r['origin_name'], 'slug'=>$r['slug'], 'tmdb_id'=>$r['tmdb_id']], $dbResults);

// 3. Check which are NOT in movies_json
$existingIds = array_column($moviesJson, 'id');
$existingTitles = array_map(fn($m) => strtolower($m['title'] ?? ''), $moviesJson);
$existingOriginals = array_map(fn($m) => strtolower($m['original'] ?? ''), $moviesJson);

$extra = [];
foreach ($dbResults as $dr) {
    $tid = (int)($dr['tmdb_id'] ?? 0);
    $nm = strtolower($dr['name'] ?? '');
    $or = strtolower($dr['origin_name'] ?? '');
    $found = ($tid > 0 && in_array($tid, $existingIds))
        || in_array($nm, $existingTitles)
        || in_array($or, $existingOriginals)
        || in_array($nm, $existingOriginals)
        || in_array($or, $existingTitles);
    if (!$found) {
        $extra[] = ['name'=>$dr['name'], 'origin'=>$dr['origin_name'], 'slug'=>$dr['slug']];
    }
}

$result['extra_from_query4'] = $extra;
$result['total_after_merge'] = count($moviesJson) + count($extra);

echo json_encode($result, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
