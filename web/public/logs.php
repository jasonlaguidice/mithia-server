<?php
// Returns logs (text/plain) for a single service
header('Content-Type: text/plain');
$services = [
  'mithia-login' => true,
  'mithia-char' => true,
  'mithia-map' => true,
];

$svc = $_GET['service'] ?? '';
$lines = (int)($_GET['lines'] ?? 150);
if (!isset($services[$svc])) { http_response_code(400); echo "unknown service"; exit; }

$descriptor = [1 => ['pipe','w'], 2 => ['pipe','w']];
$cmd = 'docker logs --tail ' . $lines . ' ' . escapeshellarg($svc) . ' 2>&1';
$p = proc_open($cmd, $descriptor, $pipes);
if (!is_resource($p)) { http_response_code(500); echo "proc_open failed"; exit; }
$out = stream_get_contents($pipes[1]);
foreach ($pipes as $h) if (is_resource($h)) fclose($h);
proc_close($p);
echo $out;