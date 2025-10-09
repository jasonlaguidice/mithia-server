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
    // Use exec with output array - simpler and captures ALL output
    $output_lines = [];
    $exit_code = -1;

    // Execute command and capture all output (2>&1 already in the command)
    exec($cmd, $output_lines, $exit_code);

    // Join all output lines
    $output = implode("\n", $output_lines);

    // Return in format: [exit_code, stdout, stderr_empty]
    // Since we use 2>&1 in commands, everything goes to stdout
    return [$exit_code, $output, ''];
}

function ok($code): bool { return (int)$code === 0; }

function safe_name(string $name, array $allow): ?string {
    return array_key_exists($name, $allow) ? $name : null;
}

function compile_service(string $container, array $info): array {
    $target = $info['target'];
    $name = $info['name'];

    $output = "=== Recompiling $name Server ===\n\n";

    // Step 1: Stop the running process inside the container (but keep container running)
    $output .= "Step 1: Stopping $target-server process...\n";
    $stopCmd = sprintf(
        'docker exec %s bash -c %s 2>&1',
        escapeshellarg($container),
        escapeshellarg("pkill -9 $target-server || true")
    );
    run_cmd($stopCmd);
    $output .= "Process stopped.\n\n";

    // Step 2: Compile
    $output .= "Step 2: Compiling...\n";
    $cmd = sprintf(
        'docker exec %s bash -c %s 2>&1',
        escapeshellarg($container),
        escapeshellarg("cd /home/RTK/rtk && make " . escapeshellarg($target))
    );

    [$code, $stdout, $stderr] = run_cmd($cmd, 600);
    $output .= $stdout;

    if (!empty($stderr)) {
        $output .= "\nSTDERR: " . $stderr;
    }

    $output .= "\n" . str_repeat('─', 50);
    $output .= "\nExit Code: " . $code . "\n";

    if (ok($code)) {
        // Step 3: Restart the container to start the new binary
        $output .= "\nStep 3: Restarting container with new binary...\n";
        run_cmd('docker restart ' . escapeshellarg($container) . ' 2>&1');
        $output .= "Container restarted successfully!";
        return ['success' => true, 'message' => "$name compiled and restarted successfully", 'output' => $output];
    } else {
        // Compilation failed - restart with old binary
        $output .= "\nCompilation FAILED! Restarting container with previous binary...\n";
        run_cmd('docker restart ' . escapeshellarg($container) . ' 2>&1');
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
