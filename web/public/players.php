<?php
// Returns a JSON object with playersOnline by inspecting TCP connections to the map server inside the container.
header('Content-Type: application/json');

function run_cmd($cmd){
  $d=[1=>['pipe','w'],2=>['pipe','w']];
  $p=proc_open($cmd,$d,$pipes);
  if(!is_resource($p)) return [1,'','proc_open failed'];
  $out=stream_get_contents($pipes[1]);
  foreach($pipes as $h) if(is_resource($h)) fclose($h);
  $code=proc_close($p);
  return [$code,$out,''];
}

// Count established connections to port 2001 (0x07D1) inside mithia-map
$awk = "awk 'NR>1 && $2 ~ /:07D1$/ && $4 == \"01\" {c++} END {print c+0}'";
$cmd4 = "docker exec mithia-map sh -lc '".$awk." /proc/net/tcp'";
$cmd6 = "docker exec mithia-map sh -lc 'test -r /proc/net/tcp6 && ".$awk." /proc/net/tcp6 || echo 0'";

[$c4,$v4] = run_cmd($cmd4);
[$c6,$v6] = run_cmd($cmd6);

$cnt = 0;
if($c4===0) $cnt += (int)trim($v4);
if($c6===0) $cnt += (int)trim($v6);

// The char server keeps one persistent connection to map; subtract 1 if any
$players = max(0, $cnt - 1);

echo json_encode([ 'playersOnline' => $players, 'rawConnections' => $cnt ]);
