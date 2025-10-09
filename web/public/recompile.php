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

    // Step 1: Compile to a temporary binary name (while server is running)
    $output .= "Step 1: Compiling new binary...\n";
    $cmd = sprintf(
        'docker exec %s bash -c %s 2>&1',
        escapeshellarg($container),
        escapeshellarg("cd /home/RTK/rtk && make " . escapeshellarg($target) . " && mv /home/RTK/rtk/$target-server /home/RTK/rtk/$target-server.new")
    );

    [$code, $stdout, $stderr] = run_cmd($cmd, 600);
    $output .= $stdout;

    if (!empty($stderr)) {
        $output .= "\nSTDERR: " . $stderr;
    }

    $output .= "\n" . str_repeat('─', 50);
    $output .= "\nExit Code: " . $code . "\n\n";

    if (!ok($code)) {
        // Clean up failed compilation attempt
        $output .= "Cleaning up failed compilation...\n";
        run_cmd(sprintf(
            'docker exec %s bash -c %s 2>&1',
            escapeshellarg($container),
            escapeshellarg("rm -f /home/RTK/rtk/$target-server.new")
        ));
        return ['success' => false, 'message' => "$name compilation failed", 'output' => $output];
    }

    // Step 2: Stop the running server process
    $output .= "Step 2: Stopping $target-server process...\n";
    $stopCmd = sprintf(
        'docker exec %s bash -c %s 2>&1',
        escapeshellarg($container),
        escapeshellarg("pkill $target-server || true")
    );
    run_cmd($stopCmd);
    $output .= "Process stopped.\n\n";

    // Step 3: Swap the binaries and restart
    $output .= "Step 3: Swapping binaries and restarting...\n";
    $swapCmd = sprintf(
        'docker exec %s bash -c %s 2>&1',
        escapeshellarg($container),
        escapeshellarg("mv /home/RTK/rtk/$target-server.new /home/RTK/rtk/$target-server && chmod +x /home/RTK/rtk/$target-server")
    );
    run_cmd($swapCmd);

    // Let Docker's restart policy start it automatically, or force restart
    sleep(2);
    run_cmd('docker restart ' . escapeshellarg($container) . ' 2>&1');

    $output .= "Container restarted with new binary!";
    return ['success' => true, 'message' => "$name compiled and restarted successfully", 'output' => $output];
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
