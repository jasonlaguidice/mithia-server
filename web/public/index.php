<?php
// Simple local dashboard for Mithia servers.
// Security note: This page has control over Docker via /var/run/docker.sock.
// It is bound to 127.0.0.1 by default in docker-compose. Do not expose publicly.

$services = [
    'mithia-login' => 'Login',
    'mithia-char'  => 'Char',
    'mithia-map'   => 'Map',
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

$action = $_POST['action'] ?? $_GET['action'] ?? '';
$target = $_POST['service'] ?? $_GET['service'] ?? '';
$target = safe_name($target, $services);
$msg = '';

if ($action && $target) {
    $allowed_actions = ['start', 'stop', 'restart'];
    if (in_array($action, $allowed_actions, true)) {
        $cmd = 'docker ' . $action . ' ' . escapeshellarg($target) . ' 2>&1';
        [$code, $out, $err] = run_cmd($cmd);
        $msg = sprintf('%s %s: %s', strtoupper($action), $services[$target], ok($code) ? 'OK' : 'FAILED') . (ok($code) ? '' : "\n$out");
    }
}

function status_of(string $name): array {
    [$c1, $raw, $e1] = run_cmd('docker inspect -f ' . escapeshellarg('{{.State.Status}}|{{.State.Running}}|{{.State.StartedAt}}') . ' ' . escapeshellarg($name) . ' 2>&1');
    $status = 'unknown'; $running = false; $startedAt = '';
    if (ok($c1)) {
        [$s, $r, $t] = array_pad(explode('|', trim($raw), 3), 3, '');
        $status = $s ?: 'created?';
        $running = ($r === 'true');
        $startedAt = $t ?: '';
    }
    [$c2, $raw2, $e2] = run_cmd('docker stats --no-stream --format ' . escapeshellarg('{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.PIDs}}') . ' ' . escapeshellarg($name) . ' 2>&1');
    $cpu = $mem = $net = $pids = '-';
    if (ok($c2)) {
        [$cpu, $mem, $net, $pids] = array_pad(explode('|', trim($raw2), 4), 4, '-');
    }
    return compact('status','running','startedAt','cpu','mem','net','pids');
}

function logs_of(string $name, int $lines = 150): string {
    [$c, $raw, $e] = run_cmd('docker logs --tail ' . (int)$lines . ' ' . escapeshellarg($name) . ' 2>&1');
    return $raw;
}

$statuses = [];
foreach ($services as $k => $_) {
  $statuses[$k] = [
    'status' => 'loading…',
    'running' => false,
    'startedAt' => '',
    'cpu' => '-',
    'mem' => '-',
    'net' => '-',
    'pids' => '-',
  ];
}

?><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Mithia Control Panel</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    :root {
      --bg-primary: #0a0a0f;
      --bg-secondary: #14141f;
      --bg-card: rgba(255, 255, 255, 0.03);
      --bg-hover: rgba(255, 255, 255, 0.05);
      --border: rgba(255, 255, 255, 0.08);
      --text-primary: #ffffff;
      --text-secondary: #94a3b8;
      --text-dim: #64748b;
      --accent: #6366f1;
      --accent-bright: #818cf8;
      --success: #22c55e;
      --error: #ef4444;
      --warning: #f59e0b;
      --gradient-1: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      --gradient-2: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      --gradient-3: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', system-ui, sans-serif;
      background: var(--bg-primary);
      color: var(--text-primary);
      line-height: 1.6;
      min-height: 100vh;
      position: relative;
      overflow-x: hidden;
    }

    body::before {
      content: '';
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: 
        radial-gradient(circle at 20% 80%, rgba(99, 102, 241, 0.08) 0%, transparent 50%),
        radial-gradient(circle at 80% 20%, rgba(139, 92, 246, 0.08) 0%, transparent 50%),
        radial-gradient(circle at 40% 40%, rgba(236, 72, 153, 0.04) 0%, transparent 50%);
      pointer-events: none;
      z-index: 1;
    }

    .container {
      max-width: 1400px;
      margin: 0 auto;
      padding: 2rem;
      position: relative;
      z-index: 2;
    }

    /* Header */
    .header {
      margin-bottom: 2rem;
      animation: slideDown 0.5s ease-out;
    }

    h1 {
      font-size: 2.5rem;
      font-weight: 800;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      margin-bottom: 0.5rem;
      letter-spacing: -0.02em;
    }

    .subtitle {
      color: var(--text-secondary);
      font-size: 1.1rem;
    }

    /* Controls Bar */
    .controls-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 2rem;
      margin: 2rem 0;
      padding: 1.25rem;
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 12px;
      backdrop-filter: blur(10px);
      animation: slideUp 0.5s ease-out 0.1s both;
      flex-wrap: wrap;
    }

    .control-group {
      display: flex;
      align-items: center;
      gap: 1rem;
    }

    .toggle-switch {
      position: relative;
      display: inline-block;
      width: 48px;
      height: 26px;
    }

    .toggle-switch input {
      opacity: 0;
      width: 0;
      height: 0;
    }

    .toggle-slider {
      position: absolute;
      cursor: pointer;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(100, 116, 139, 0.3);
      transition: all 0.3s ease;
      border-radius: 34px;
    }

    .toggle-slider:before {
      position: absolute;
      content: "";
      height: 20px;
      width: 20px;
      left: 3px;
      bottom: 3px;
      background: white;
      transition: all 0.3s ease;
      border-radius: 50%;
      box-shadow: 0 2px 4px rgba(0,0,0,0.2);
    }

    input:checked + .toggle-slider {
      background: var(--accent);
    }

    input:checked + .toggle-slider:before {
      transform: translateX(22px);
    }

    .toggle-label {
      color: var(--text-secondary);
      font-size: 0.95rem;
      font-weight: 500;
      user-select: none;
      cursor: pointer;
      transition: color 0.3s;
    }

    .toggle-label:hover {
      color: var(--text-primary);
    }

    /* Player Stats */
    .player-stats {
      display: flex;
      flex-direction: column;
      gap: 0.25rem;
    }

    #playersOnline {
      font-size: 1.1rem;
      font-weight: 600;
      color: var(--success);
    }

    #playersDetail {
      font-size: 0.85rem;
      color: var(--text-secondary);
      max-width: 400px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    /* Message Alert */
    .msg {
      padding: 1rem 1.25rem;
      margin: 1rem 0;
      background: rgba(99, 102, 241, 0.1);
      border: 1px solid rgba(99, 102, 241, 0.3);
      border-radius: 8px;
      white-space: pre-wrap;
      font-family: 'Monaco', 'Courier New', monospace;
      font-size: 0.9rem;
      animation: slideUp 0.3s ease-out;
    }

    /* Service Grid */
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
      gap: 1.5rem;
      margin-bottom: 2rem;
    }

    .card {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 1.5rem;
      backdrop-filter: blur(10px);
      transition: all 0.3s ease;
      animation: slideUp 0.5s ease-out;
      animation-fill-mode: both;
      position: relative;
      overflow: hidden;
    }

    .card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 2px;
      background: var(--gradient-1);
      opacity: 0;
      transition: opacity 0.3s;
    }

    .card:hover {
      transform: translateY(-2px);
      background: var(--bg-hover);
      border-color: rgba(255, 255, 255, 0.15);
    }

    .card:hover::before {
      opacity: 1;
    }

    .card:nth-child(1) { animation-delay: 0.2s; }
    .card:nth-child(2) { animation-delay: 0.3s; }
    .card:nth-child(3) { animation-delay: 0.4s; }

    .service-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 1rem;
    }

    .service-title {
      font-size: 1.5rem;
      font-weight: 700;
      color: var(--text-primary);
    }

    .service-id {
      font-size: 0.85rem;
      color: var(--text-dim);
      font-weight: 400;
    }

    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
      font-size: 0.85rem;
      font-weight: 600;
      transition: all 0.3s;
    }

    .status-indicator {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      animation: pulse 2s infinite;
    }

    .status.running .status-badge {
      background: rgba(34, 197, 94, 0.15);
      color: var(--success);
    }

    .status.running .status-indicator {
      background: var(--success);
      box-shadow: 0 0 10px var(--success);
    }

    .status.stopped .status-badge {
      background: rgba(239, 68, 68, 0.15);
      color: var(--error);
    }

    .status.stopped .status-indicator {
      background: var(--error);
      animation: none;
    }

    /* Stats Grid */
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 1rem;
      margin: 1rem 0;
    }

    .stat-item {
      display: flex;
      flex-direction: column;
      gap: 0.25rem;
    }

    .stat-label {
      color: var(--text-dim);
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      font-weight: 600;
    }

    .stat-value {
      color: var(--text-primary);
      font-size: 1rem;
      font-weight: 600;
      font-family: 'Monaco', 'Courier New', monospace;
    }

    .started-time {
      color: var(--text-secondary);
      font-size: 0.85rem;
      margin: 1rem 0;
      padding-top: 1rem;
      border-top: 1px solid var(--border);
    }

    /* Control Buttons */
    .controls {
      display: flex;
      gap: 0.75rem;
      margin-top: 1.5rem;
      flex-wrap: wrap;
    }

    .controls form {
      flex: 1;
      min-width: 80px;
    }

    button {
      width: 100%;
      padding: 0.75rem 1rem;
      border: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.03);
      color: var(--text-primary);
      border-radius: 8px;
      font-size: 0.9rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s ease;
      position: relative;
      overflow: hidden;
    }

    button::before {
      content: '';
      position: absolute;
      top: 50%;
      left: 50%;
      width: 0;
      height: 0;
      background: radial-gradient(circle, rgba(255,255,255,0.15) 0%, transparent 70%);
      transform: translate(-50%, -50%);
      transition: width 0.5s, height 0.5s;
    }

    button:hover:not(:disabled) {
      background: rgba(255, 255, 255, 0.08);
      transform: translateY(-1px);
      border-color: rgba(255, 255, 255, 0.2);
    }

    button:hover:not(:disabled)::before {
      width: 100px;
      height: 100px;
    }

    button:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }

    button[value="start"]:not(:disabled) {
      background: rgba(34, 197, 94, 0.15);
      border-color: rgba(34, 197, 94, 0.3);
      color: var(--success);
    }

    button[value="stop"]:not(:disabled) {
      background: rgba(239, 68, 68, 0.15);
      border-color: rgba(239, 68, 68, 0.3);
      color: var(--error);
    }

    button[value="restart"]:not(:disabled) {
      background: rgba(245, 158, 11, 0.15);
      border-color: rgba(245, 158, 11, 0.3);
      color: var(--warning);
    }

    button.compile-btn:not(:disabled) {
      background: rgba(139, 92, 246, 0.15);
      border-color: rgba(139, 92, 246, 0.3);
      color: #a78bfa;
    }

    button.compile-btn:hover:not(:disabled) {
      background: rgba(139, 92, 246, 0.25);
      border-color: rgba(139, 92, 246, 0.5);
    }

    /* Console */
    .console-card {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 1.5rem;
      backdrop-filter: blur(10px);
      animation: slideUp 0.5s ease-out 0.5s both;
    }

    .console-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 1rem;
    }

    .console-title {
      font-size: 1.5rem;
      font-weight: 700;
    }

    .tabs {
      display: flex;
      gap: 0.5rem;
      align-items: center;
      flex-wrap: wrap;
    }

    .tab-group {
      display: flex;
      background: rgba(255, 255, 255, 0.05);
      border-radius: 8px;
      padding: 0.25rem;
    }

    .tab {
      padding: 0.5rem 1.25rem;
      background: transparent;
      border: none;
      color: var(--text-secondary);
      border-radius: 6px;
      cursor: pointer;
      transition: all 0.3s;
      font-weight: 600;
      font-size: 0.9rem;
    }

    .tab:hover {
      color: var(--text-primary);
    }

    .tab.active {
      background: var(--accent);
      color: white;
      box-shadow: 0 2px 8px rgba(99, 102, 241, 0.3);
    }

    #console-log {
      background: #0a0a0f;
      border: 1px solid var(--border);
      color: #e2e8f0;
      padding: 1.25rem;
      border-radius: 8px;
      max-height: 400px;
      overflow: auto;
      font-family: 'Monaco', 'Courier New', monospace;
      font-size: 0.85rem;
      line-height: 1.5;
      white-space: pre-wrap;
      word-wrap: break-word;
    }

    #console-log::-webkit-scrollbar {
      width: 8px;
    }

    #console-log::-webkit-scrollbar-track {
      background: rgba(255, 255, 255, 0.02);
      border-radius: 4px;
    }

    #console-log::-webkit-scrollbar-thumb {
      background: rgba(255, 255, 255, 0.1);
      border-radius: 4px;
    }

    #console-log::-webkit-scrollbar-thumb:hover {
      background: rgba(255, 255, 255, 0.15);
    }

    /* Footer */
    .footer {
      text-align: center;
      color: var(--text-dim);
      font-size: 0.85rem;
      margin-top: 3rem;
      padding-top: 2rem;
      border-top: 1px solid var(--border);
      animation: fadeIn 0.5s ease-out 0.6s both;
    }

    /* Animations */
    @keyframes slideDown {
      from {
        opacity: 0;
        transform: translateY(-20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    @keyframes slideUp {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    @keyframes pulse {
      0%, 100% {
        opacity: 1;
      }
      50% {
        opacity: 0.5;
      }
    }

    /* Loading animation */
    .loading {
      display: inline-block;
      width: 20px;
      height: 20px;
      border: 2px solid rgba(255, 255, 255, 0.1);
      border-top-color: var(--accent);
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    /* Responsive */
    @media (max-width: 768px) {
      .container {
        padding: 1rem;
      }

      h1 {
        font-size: 2rem;
      }

      .controls-bar {
        flex-direction: column;
        align-items: stretch;
        gap: 1rem;
      }

      .grid {
        grid-template-columns: 1fr;
      }

      .stats-grid {
        grid-template-columns: 1fr;
      }

      .tabs {
        flex-direction: column;
        align-items: stretch;
      }

      .tab-group {
        width: 100%;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <header class="header">
      <h1>Mithia Control Panel</h1>
      <p class="subtitle">Manage and monitor your game servers in real-time</p>
    </header>

    <div class="controls-bar">
      <div class="control-group">
        <label class="toggle-switch">
          <input type="checkbox" id="autoRefresh" />
          <span class="toggle-slider"></span>
        </label>
        <label for="autoRefresh" class="toggle-label">Auto-refresh (5s)</label>
      </div>
      <div class="player-stats">
        <span id="playersOnline">Players online: …</span>
        <span id="playersDetail"></span>
      </div>
    </div>

    <?php if ($msg): ?>
      <div class="msg"><?php echo htmlspecialchars($msg, ENT_QUOTES, 'UTF-8'); ?></div>
    <?php endif; ?>

    <div style="margin-bottom: 1.5rem; padding: 1rem; background: rgba(59, 130, 246, 0.1); border: 1px solid rgba(59, 130, 246, 0.2); border-radius: 8px;">
      <p style="margin: 0 0 0.5rem 0; font-size: 0.875rem; color: #94a3b8;">
        <strong>Workflow:</strong> After <code>git pull</code> on the server, click <strong>Reload Lua</strong> for script changes or <strong>Recompile</strong> for C code changes.
      </p>
      <div style="display: flex; justify-content: flex-end; gap: 1rem;">
        <button class="compile-btn" onclick="reloadScripts()" style="padding: 0.75rem 1.5rem; font-size: 1rem; font-weight: 600; background: rgba(34, 197, 94, 0.15); border-color: rgba(34, 197, 94, 0.3); color: #4ade80;">
          Reload Lua Scripts
        </button>
        <button class="compile-btn" onclick="compileService('all')" style="padding: 0.75rem 1.5rem; font-size: 1rem; font-weight: 600;">
          Recompile All Servers
        </button>
      </div>
    </div>

    <div class="grid">
      <?php foreach ($services as $id => $label): $st = $statuses[$id]; $isRun = !empty($st['running']); ?>
        <div class="card">
          <div class="service-header">
            <div>
              <div class="service-title"><?php echo htmlspecialchars($label); ?></div>
              <div class="service-id"><?php echo htmlspecialchars($id); ?></div>
            </div>
            <div class="status <?php echo $isRun ? 'running' : 'stopped'; ?>" id="status-<?php echo htmlspecialchars($id); ?>">
              <div class="status-badge">
                <span class="status-indicator"></span>
                <span><?php echo htmlspecialchars($st['status']); ?></span>
              </div>
            </div>
          </div>

          <div class="stats-grid">
            <div class="stat-item">
              <span class="stat-label">CPU</span>
              <span class="stat-value" id="cpu-<?php echo htmlspecialchars($id); ?>"><?php echo htmlspecialchars($st['cpu']); ?></span>
            </div>
            <div class="stat-item">
              <span class="stat-label">Memory</span>
              <span class="stat-value" id="mem-<?php echo htmlspecialchars($id); ?>"><?php echo htmlspecialchars($st['mem']); ?></span>
            </div>
            <div class="stat-item">
              <span class="stat-label">Network</span>
              <span class="stat-value" id="net-<?php echo htmlspecialchars($id); ?>"><?php echo htmlspecialchars($st['net']); ?></span>
            </div>
            <div class="stat-item">
              <span class="stat-label">PIDs</span>
              <span class="stat-value" id="pids-<?php echo htmlspecialchars($id); ?>"><?php echo htmlspecialchars($st['pids']); ?></span>
            </div>
          </div>

          <div class="started-time">
            Started: <span id="started-<?php echo htmlspecialchars($id); ?>"><?php echo htmlspecialchars($st['startedAt']); ?></span>
          </div>

          <div class="controls">
            <form method="post">
              <input type="hidden" name="service" value="<?php echo htmlspecialchars($id); ?>" />
              <button name="action" value="start" <?php echo $isRun ? 'disabled' : ''; ?>>Start</button>
            </form>
            <form method="post">
              <input type="hidden" name="service" value="<?php echo htmlspecialchars($id); ?>" />
              <button name="action" value="stop" <?php echo !$isRun ? 'disabled' : ''; ?>>Stop</button>
            </form>
            <form method="post">
              <input type="hidden" name="service" value="<?php echo htmlspecialchars($id); ?>" />
              <button name="action" value="restart">Restart</button>
            </form>
            <button class="compile-btn" onclick="compileService('<?php echo htmlspecialchars($id); ?>')">Recompile</button>
          </div>
        </div>
      <?php endforeach; ?>
    </div>

    <div class="console-card">
      <div class="console-header">
        <h2 class="console-title">Console</h2>
        <div class="tabs" id="consoleTabs">
          <div class="tab-group">
            <button class="tab" data-service="mithia-login">Login</button>
            <button class="tab" data-service="mithia-char">Char</button>
            <button class="tab" data-service="mithia-map">Map</button>
          </div>
          <div class="control-group">
            <label class="toggle-switch">
              <input type="checkbox" id="followConsole" checked />
              <span class="toggle-slider"></span>
            </label>
            <label for="followConsole" class="toggle-label">Auto-scroll</label>
          </div>
        </div>
      </div>
      <pre id="console-log">Select a tab to view logs…</pre>
    </div>

    <div class="footer">
      Exposed on LAN at port 8080 with basic auth • Default credentials: admin / changeme
    </div>
  </div>

  <script>
    const services = <?php echo json_encode(array_keys($services)); ?>;
    let activeConsole = (services.includes('mithia-map') ? 'mithia-map' : services[0]);
    let refreshTimer = null;

    function fetchStatus() {
      return fetch('status.php')
        .then(r => r.json())
        .then(data => {
          for (const id of services) {
            const st = data[id];
            if (!st) continue;
            
            const statusEl = document.getElementById('status-' + id);
            const cpuEl = document.getElementById('cpu-' + id);
            const memEl = document.getElementById('mem-' + id);
            const netEl = document.getElementById('net-' + id);
            const pidsEl = document.getElementById('pids-' + id);
            const startedEl = document.getElementById('started-' + id);
            
            if (statusEl) {
              const badge = statusEl.querySelector('.status-badge span:last-child');
              if (badge) badge.textContent = st.status || '-';
              statusEl.classList.remove('running', 'stopped');
              statusEl.classList.add(st.running ? 'running' : 'stopped');
            }
            
            if (cpuEl) {
              const newValue = st.cpu || '-';
              if (cpuEl.textContent !== newValue) {
                cpuEl.style.transition = 'color 0.3s';
                cpuEl.style.color = 'var(--accent-bright)';
                cpuEl.textContent = newValue;
                setTimeout(() => { cpuEl.style.color = ''; }, 300);
              }
            }
            if (memEl) memEl.textContent = st.mem || '-';
            if (netEl) netEl.textContent = st.net || '-';
            if (pidsEl) pidsEl.textContent = st.pids || '-';
            if (startedEl) {
              if (st.startedAt) {
                const date = new Date(st.startedAt);
                const formatted = date.toLocaleString('en-US', {
                  month: 'short',
                  day: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit'
                });
                startedEl.textContent = formatted;
              } else {
                startedEl.textContent = '-';
              }
            }
            
            // Update button states
            const card = statusEl.closest('.card');
            if (card) {
              const startBtn = card.querySelector('button[value="start"]');
              const stopBtn = card.querySelector('button[value="stop"]');
              if (startBtn) startBtn.disabled = st.running;
              if (stopBtn) stopBtn.disabled = !st.running;
            }
          }
        })
        .catch(err => console.error('Status fetch error:', err));
    }

    function updateConsoleTabsUI() {
      const tabs = document.querySelectorAll('#consoleTabs .tab');
      tabs.forEach(btn => {
        if (btn.getAttribute('data-service') === activeConsole) {
          btn.classList.add('active');
        } else {
          btn.classList.remove('active');
        }
      });
    }

    function fetchConsoleLogs() {
      return fetch('logs.php?service=' + encodeURIComponent(activeConsole) + '&lines=150')
        .then(r => r.text())
        .then(text => {
          const pre = document.getElementById('console-log');
          if (!pre) return;
          
          const atBottom = Math.abs(pre.scrollHeight - pre.scrollTop - pre.clientHeight) < 4;
          const oldText = pre.textContent;
          
          if (oldText !== text) {
            pre.textContent = text || 'No logs available';
            const follow = document.getElementById('followConsole');
            if ((follow && follow.checked) || atBottom) {
              pre.scrollTop = pre.scrollHeight;
            }
          }
        })
        .catch(err => console.error('Logs fetch error:', err));
    }

    function fetchWithTimeout(resource, options = {}) {
      const { timeout = 2500 } = options;
      return Promise.race([
        fetch(resource, options),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), timeout))
      ]);
    }

    function fetchPlayers() {
      return fetchWithTimeout('metrics_players.php', { timeout: 2500 })
        .then(r => r.json())
        .then(data => {
          const el = document.getElementById('playersOnline');
          const detail = document.getElementById('playersDetail');
          
          if (el && typeof data.online === 'number') {
            const count = data.online;
            el.innerHTML = `Players online: <span style="color: ${count > 0 ? '#22c55e' : '#64748b'}">${count}</span>`;
          }
          
          if (detail) {
            if (Array.isArray(data.players) && data.players.length > 0) {
              const names = data.players.map(p => `${p.name} (${p.mapName || 'Unknown'})`);
              const maxShow = 10;
              const shown = names.slice(0, maxShow).join(', ');
              detail.textContent = shown + (names.length > maxShow ? `, and ${names.length - maxShow} more…` : '');
            } else {
              detail.textContent = 'No players currently online';
            }
          }
        })
        .catch(() => {
          return fetchWithTimeout('players.php', { timeout: 1500 })
            .then(r => r.json())
            .then(data => {
              const el = document.getElementById('playersOnline');
              const detail = document.getElementById('playersDetail');
              if (el && typeof data.playersOnline === 'number') {
                el.innerHTML = `Players online: <span style="color: #64748b">${data.playersOnline}</span> (legacy)`;
              }
              if (detail) detail.textContent = '';
            })
            .catch(() => {/* ignore */});
        });
    }

    function refreshAll() {
      Promise.all([
        fetchConsoleLogs(),
        fetchPlayers(),
        fetchStatus()
      ]).catch(err => console.error('Refresh error:', err));
    }

    // Event listeners
    document.addEventListener('change', (e) => {
      if (e.target && e.target.id === 'autoRefresh') {
        if (e.target.checked) {
          refreshAll();
          refreshTimer = setInterval(refreshAll, 5000);
        } else {
          if (refreshTimer) {
            clearInterval(refreshTimer);
            refreshTimer = null;
          }
        }
      }
    });

    document.addEventListener('click', (e) => {
      const btn = e.target.closest('#consoleTabs .tab');
      if (btn) {
        const svc = btn.getAttribute('data-service');
        if (svc && services.includes(svc)) {
          activeConsole = svc;
          updateConsoleTabsUI();
          fetchConsoleLogs();
        }
      }
    });

    // Initial load
    document.addEventListener('DOMContentLoaded', () => {
      try {
        updateConsoleTabsUI();
        refreshAll();
        
        // Enable auto-refresh by default
        const autoRefresh = document.getElementById('autoRefresh');
        if (autoRefresh) {
          autoRefresh.checked = true;
          refreshTimer = setInterval(refreshAll, 5000);
        }
      } catch (err) {
        console.error('Initial load error:', err);
      }
    });

    // Clean up on page unload
    window.addEventListener('beforeunload', () => {
      if (refreshTimer) {
        clearInterval(refreshTimer);
      }
    });

    // Recompile service function
    async function compileService(service) {
      const btn = event.target;
      btn.disabled = true;
      btn.textContent = service === 'all' ? 'Compiling All...' : 'Compiling...';

      try {
        const formData = new FormData();
        formData.append('action', 'compile');
        formData.append('service', service);

        const response = await fetch('/recompile.php', {
          method: 'POST',
          body: formData
        });

        const result = await response.json();

        if (service === 'all') {
          // Show results for all services
          let message = 'Compilation Results:\n\n';
          let hasErrors = false;
          for (const [svc, res] of Object.entries(result.results)) {
            const status = res.success ? '✅ SUCCESS' : '❌ FAILED';
            message += `${svc.toUpperCase()}: ${status}\n`;
            message += `${res.message}\n`;
            if (res.output && res.output.trim()) {
              message += `\nOutput:\n${res.output}\n`;
            }
            message += '\n' + '─'.repeat(50) + '\n\n';
            if (!res.success) hasErrors = true;
          }
          alert((hasErrors ? '⚠️ ' : '✅ ') + message);
        } else {
          // Show result for single service
          if (result.result.success) {
            let msg = `✅ ${result.service.toUpperCase()} compiled and restarted successfully!`;
            if (result.result.output && result.result.output.trim()) {
              msg += `\n\nOutput:\n${result.result.output}`;
            }
            alert(msg);
          } else {
            alert(`❌ Compilation failed for ${result.service.toUpperCase()}:\n\n${result.result.message}\n\nOutput:\n${result.result.output}`);
          }
        }

        // Reload page to show updated status
        setTimeout(() => window.location.reload(), 1000);
      } catch (error) {
        alert('Error: ' + error.message);
      } finally {
        btn.disabled = false;
        btn.textContent = service === 'all' ? 'Recompile All Servers' : 'Recompile';
      }
    }

    // Reload Lua scripts function
    async function reloadScripts() {
      const btn = event.target;
      const originalText = btn.textContent;
      btn.disabled = true;
      btn.textContent = 'Reloading...';

      try {
        const formData = new FormData();
        formData.append('action', 'reload');

        const response = await fetch('/recompile.php', {
          method: 'POST',
          body: formData
        });

        const result = await response.json();

        if (result.result.success) {
          let msg = '✅ Lua scripts reloaded successfully!';
          if (result.result.output && result.result.output.trim()) {
            msg += '\n\nOutput:\n' + result.result.output;
          }
          alert(msg);
        } else {
          alert('❌ Lua reload failed:\n\n' + result.result.output);
        }
      } catch (error) {
        alert('Error: ' + error.message);
      } finally {
        btn.disabled = false;
        btn.textContent = originalText;
      }
    }
  </script>
</body>
</html>