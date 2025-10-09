<?php
// Recompile server binaries endpoint
// Compiles C code inside running containers without full rebuild

set_time_limit(600); // 10 minute max execution time
header('Content-Type: application/json');

$services = [
    'mithia-login' => ['name' => 'Login', 'target' => 'login'],
    'mithia-char'  => ['name' => 'Char', 'target' => 'char'],
    'mithia-map'   => ['name' => 'Map', 'target' => 'map'],
];

function run_cmd(string $cmd, int $timeout = 300): array {
    $descriptor = [1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = proc_open($cmd, $descriptor, $pipes);
    if (!\is_resource($proc)) return [1, '', 'proc_open failed'];

    // Set non-blocking mode on pipes
    stream_set_blocking($pipes[1], false);
    stream_set_blocking($pipes[2], false);

    $stdout = '';
    $stderr = '';
    $start = time();

    // Read output with timeout
    while (time() - $start < $timeout) {
        $status = proc_get_status($proc);
        if (!$status['running']) break;

        $out = stream_get_contents($pipes[1]);
        $err = stream_get_contents($pipes[2]);
        if ($out !== false) $stdout .= $out;
        if ($err !== false) $stderr .= $err;

        usleep(100000); // 100ms sleep to avoid busy-waiting
    }

    // Final read
    $stdout .= stream_get_contents($pipes[1]);
    $stderr .= stream_get_contents($pipes[2]);

    foreach ($pipes as $p) { if (\is_resource($p)) fclose($p); }

    // Check if timed out
    $status = proc_get_status($proc);
    if ($status['running']) {
        proc_terminate($proc, 9); // SIGKILL
        proc_close($proc);
        return [1, $stdout, $stderr . "\n[TIMEOUT after {$timeout}s]"];
    }

    $code = proc_close($proc);
    return [$code, $stdout, $stderr];
}

function ok($code): bool { return (int)$code === 0; }

function safe_name(string $name, array $allow): ?string {
    return array_key_exists($name, $allow) ? $name : null;
}

function compile_service(string $container, array $info): array {
    $target = $info['target'];
    $name = $info['name'];

    // Run make from the main rtk directory to compile common + specific server
    // This ensures all dependencies and variables are properly set
    $cmd = sprintf(
        'docker exec %s bash -c %s 2>&1',
        escapeshellarg($container),
        escapeshellarg("cd /home/RTK/rtk && make " . escapeshellarg($target))
    );

    [$code, $stdout, $stderr] = run_cmd($cmd, 600); // 10 minute timeout for compilation
    $output = trim($stdout . "\n" . $stderr);

    // Check if error is because container not running
    if (strpos($output, 'No such container') !== false || strpos($output, 'is not running') !== false) {
        return ['success' => false, 'message' => "$name container is not running", 'output' => $output];
    }

    if (ok($code)) {
        // Restart the service after successful compile
        run_cmd('docker restart ' . escapeshellarg($container) . ' 2>&1');
        return ['success' => true, 'message' => "$name compiled and restarted successfully", 'output' => $output];
    } else {
        return ['success' => false, 'message' => "$name compilation failed", 'output' => $output];
    }
}

function reload_lua(): array {
    // Execute /reloadlua command in map server via docker exec
    $reloadCmd = 'docker exec mithia-map /home/RTK/rtk/map-server --lua-reload 2>&1';
    [$reloadCode, $reloadOut, $reloadErr] = run_cmd($reloadCmd, 10);

    $output = trim($reloadOut . "\n" . $reloadErr);

    if (ok($reloadCode)) {
        return ['success' => true, 'message' => 'Lua scripts reloaded successfully', 'output' => $output];
    } else {
        return ['success' => false, 'message' => 'Lua reload failed', 'output' => $output];
    }
}

// Handle request
$action = $_POST['action'] ?? '';
$target = $_POST['service'] ?? '';
$target = safe_name($target, $services);

if ($action === 'compile') {
    if ($target === 'all') {
        // Compile all services
        $results = [];
        foreach ($services as $container => $info) {
            $results[$container] = compile_service($container, $info);
        }
        echo json_encode(['action' => 'compile_all', 'results' => $results]);
    } elseif ($target) {
        // Compile single service
        $result = compile_service($target, $services[$target]);
        echo json_encode(['action' => 'compile', 'service' => $target, 'result' => $result]);
    } else {
        echo json_encode(['error' => 'Invalid service']);
    }
} elseif ($action === 'reload') {
    // Reload Lua scripts only
    $result = reload_lua();
    echo json_encode(['action' => 'reload', 'result' => $result]);
} else {
    echo json_encode(['error' => 'Invalid action']);
}
?>
