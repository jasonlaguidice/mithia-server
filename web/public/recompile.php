<?php
// Recompile server binaries endpoint
// Compiles C code inside running containers without full rebuild

header('Content-Type: application/json');

$services = [
    'mithia-login' => ['name' => 'Login', 'dir' => '/home/RTK/rtk/src/login'],
    'mithia-char'  => ['name' => 'Char', 'dir' => '/home/RTK/rtk/src/char'],
    'mithia-map'   => ['name' => 'Map', 'dir' => '/home/RTK/rtk/src/map'],
];

function run_cmd(string $cmd): array {
    $descriptor = [1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
    $proc = proc_open($cmd, $descriptor, $pipes);
    if (!\is_resource($proc)) return [1, '', 'proc_open failed'];
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    foreach ($pipes as $p) { if (\is_resource($p)) fclose($p); }
    $code = proc_close($proc);
    return [$code, $stdout, $stderr];
}

function ok($code): bool { return (int)$code === 0; }

function safe_name(string $name, array $allow): ?string {
    return array_key_exists($name, $allow) ? $name : null;
}

function compile_service(string $container, array $info): array {
    $compileDir = $info['dir'];
    $name = $info['name'];

    // Check if container is running
    [$checkCode, $checkOut, $checkErr] = run_cmd('docker inspect -f {{.State.Running}} ' . escapeshellarg($container) . ' 2>&1');
    if (!ok($checkCode) || trim($checkOut) !== 'true') {
        return ['success' => false, 'message' => "$name container is not running", 'output' => ''];
    }

    // Run make clean && make inside container
    $cmd = sprintf(
        'docker exec %s bash -c %s 2>&1',
        escapeshellarg($container),
        escapeshellarg("cd $compileDir && make clean && make")
    );

    [$code, $stdout, $stderr] = run_cmd($cmd);
    $output = trim($stdout . "\n" . $stderr);

    if (ok($code)) {
        // Restart the service after successful compile
        run_cmd('docker restart ' . escapeshellarg($container) . ' 2>&1');
        return ['success' => true, 'message' => "$name compiled and restarted successfully", 'output' => $output];
    } else {
        return ['success' => false, 'message' => "$name compilation failed", 'output' => $output];
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
} else {
    echo json_encode(['error' => 'Invalid action']);
}
?>
