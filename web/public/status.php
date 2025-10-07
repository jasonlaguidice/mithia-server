<?php
// Returns JSON status for all services
header('Content-Type: application/json');
$services = [
  'mithia-login' => 'Login',
  'mithia-char' => 'Char',
  'mithia-map' => 'Map',
];

function run_cmd(string $cmd): array {
  $descriptor = [1 => ['pipe','w'], 2 => ['pipe','w']];
  $p = proc_open($cmd, $descriptor, $pipes);
  if (!is_resource($p)) return [1,'','proc_open failed'];
  $out = stream_get_contents($pipes[1]);
  $err = stream_get_contents($pipes[2]);
  foreach ($pipes as $h) if (is_resource($h)) fclose($h);
  $code = proc_close($p);
  return [$code,$out,$err];
}

function ok($c){ return (int)$c===0; }

function status_of(string $name): array {
  [$c1,$raw] = run_cmd('docker inspect -f ' . escapeshellarg('{{.State.Status}}|{{.State.Running}}|{{.State.StartedAt}}') . ' ' . escapeshellarg($name) . ' 2>&1');
  $status='unknown'; $running=false; $startedAt='';
  if (ok($c1)) { [$s,$r,$t] = array_pad(explode('|', trim($raw), 3),3,''); $status=$s?:'created?'; $running=($r==='true'); $startedAt=$t?:''; }
  [$c2,$raw2] = run_cmd('docker stats --no-stream --format ' . escapeshellarg('{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.PIDs}}') . ' ' . escapeshellarg($name) . ' 2>&1');
  $cpu='-'; $mem='-'; $net='-'; $pids='-';
  if (ok($c2)) { [$cpu,$mem,$net,$pids] = array_pad(explode('|', trim($raw2), 4),4,'-'); }
  return compact('status','running','startedAt','cpu','mem','net','pids');
}

$result = [];
foreach ($services as $id=>$_) { $result[$id] = status_of($id); }

echo json_encode($result);
