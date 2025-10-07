<?php
// PHP relay for internal map-server metrics
// GET /metrics_players.php -> proxies to http://mithia-map:9000/metrics/players

header('Content-Type: application/json');

$target = getenv('MITHIA_MAP_METRICS_URL');
if (!$target) {
    $target = 'http://mithia-map:9000/metrics/players';
}

$ch = curl_init($target);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
// keep timeouts small so the dashboard remains responsive
curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 1);
curl_setopt($ch, CURLOPT_TIMEOUT, 2);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Accept: application/json']);

$body = curl_exec($ch);
$err  = curl_error($ch);
$code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($body !== false && $code >= 200 && $code < 300) {
    echo $body;
    exit;
}

http_response_code(502);
$response = [
    'error' => 'upstream_unavailable',
    'status' => $code,
];
if ($err) {
    $response['detail'] = $err;
}
echo json_encode($response);
