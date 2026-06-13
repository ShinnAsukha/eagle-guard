<?php
/**
 * Eagle Guard API v3.3 — Düzeltilmiş
 * - iptables nf_tables/legacy otomatik fallback
 * - Terminal exit code UI'ya taşındı, sudo otomatik
 * - Firewall kuralları eagle-guard rules-* fallback ile
 */
declare(strict_types=1);

// CORS + JSON header
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Cache-Control: no-store, no-cache, must-revalidate');

// OPTIONS preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit; }

// ── Sabitler ──────────────────────────────────────────────────────
define('EG',    '/opt/eagle-guard');
define('STATS', EG.'/data/stats.json');
define('BLKD',  EG.'/data/blocked.json');
define('ALRT',  EG.'/data/alerts.json');
define('TRF',   EG.'/data/traffic.json');
define('LOGF',  EG.'/logs/eagle.log');
define('CONF',  EG.'/config/eagle.conf');
define('WL',    EG.'/config/whitelist.txt');
define('BIN',   EG.'/scripts/eagle-guard.sh');

// ── Hata yönetimi ─────────────────────────────────────────────────
function ok(mixed $d, string $m = ''): void {
    echo json_encode(['ok' => true, 'data' => $d, 'msg' => $m, 'ts' => date('c')],
        JSON_UNESCAPED_UNICODE | JSON_PARTIAL_OUTPUT_ON_ERROR);
    exit;
}
function fail(string $e, int $c = 400): void {
    http_response_code($c);
    echo json_encode(['ok' => false, 'error' => $e, 'ts' => date('c')]);
    exit;
}
function jr(string $f): array {
    if (!file_exists($f)) return [];
    $raw = @file_get_contents($f);
    if ($raw === false) return [];
    $d = json_decode($raw, true);
    return is_array($d) ? $d : [];
}

// ── Shell komutu çalıştır ─────────────────────────────────────────
// sudo yerine doğrudan script çağrısı + output capture
function run(string $args): array {
    $cmd = 'sudo ' . escapeshellarg(BIN) . ' ' . $args . ' 2>&1';
    $output = [];
    $code = 0;
    exec($cmd, $output, $code);
    return ['out' => $output, 'code' => $code];
}

// iptables'ı doğrudan çalıştır (sudo ile) — nf_tables/legacy otomatik fallback
function ipt(string $args): array {
    $candidates = [
        '/usr/sbin/iptables',
        '/sbin/iptables',
        '/usr/sbin/iptables-nft',
        '/usr/sbin/iptables-legacy',
    ];
    $last = [];
    foreach ($candidates as $bin) {
        if (!is_executable($bin)) continue;
        $out = []; $code = 0;
        exec('sudo ' . $bin . ' ' . $args . ' 2>&1', $out, $code);
        $joined = implode("\n", $out);
        // nf_tables incompatibility — diğer backend'i dene
        if (stripos($joined, 'incompatible') !== false ||
            stripos($joined, 'use \'nft\' tool') !== false ||
            stripos($joined, "No chain/target/match by that name") !== false) {
            $last = $out;
            continue;
        }
        if ($code === 0 || !empty($out)) return $out;
        $last = $out;
    }
    // Son çare: eagle-guard scriptinin kendi komutu (aynı backend'i kullanıyor)
    return $last;
}

function ipt6(string $args): array {
    $out = [];
    exec('sudo /sbin/ip6tables ' . $args . ' 2>&1', $out);
    return $out;
}

function valid_ip(string $ip): bool {
    return (bool) filter_var($ip, FILTER_VALIDATE_IP);
}

// ── Sistem metrikleri ─────────────────────────────────────────────
function get_cpu(): float {
    $l = sys_getloadavg();
    $cores = (int) trim(shell_exec('nproc') ?? '1');
    if ($cores < 1) $cores = 1;
    return round($l[0] / $cores * 100, 1);
}

function get_mem(): array {
    $raw = shell_exec('free -b 2>/dev/null') ?? '';
    foreach (explode("\n", $raw) as $line) {
        if (str_starts_with($line, 'Mem:')) {
            $p = preg_split('/\s+/', trim($line));
            $t = (int)($p[1] ?? 0);
            $u = (int)($p[2] ?? 0);
            $f = (int)($p[3] ?? 0);
            return [
                'total' => $t, 'used' => $u, 'free' => $f,
                'pct'   => $t > 0 ? round($u / $t * 100, 1) : 0,
                'total_mb' => (int)round($t / 1048576),
                'used_mb'  => (int)round($u / 1048576),
            ];
        }
    }
    return ['total' => 0, 'used' => 0, 'free' => 0, 'pct' => 0, 'total_mb' => 0, 'used_mb' => 0];
}

function get_disk(): array {
    $raw = shell_exec('df -B1 / 2>/dev/null') ?? '';
    $lines = array_values(array_filter(explode("\n", trim($raw))));
    if (isset($lines[1])) {
        $p = preg_split('/\s+/', trim($lines[1]));
        $t = (int)($p[1] ?? 0);
        $u = (int)($p[2] ?? 0);
        return [
            'total' => $t, 'used' => $u,
            'pct'   => $t > 0 ? round($u / $t * 100, 1) : 0,
            'total_gb' => round($t / 1073741824, 1),
            'used_gb'  => round($u / 1073741824, 1),
        ];
    }
    return ['total' => 0, 'used' => 0, 'pct' => 0, 'total_gb' => 0, 'used_gb' => 0];
}

function get_net(): array {
    $iface = trim(shell_exec("ip route 2>/dev/null | awk '/default/{print \$5; exit}'") ?? '');
    if (!$iface) $iface = 'eth0';
    $rd = fn($k) => (int)(@file_get_contents("/sys/class/net/$iface/statistics/$k") ?: 0);
    return [
        'iface'      => $iface,
        'rx_bytes'   => $rd('rx_bytes'),
        'tx_bytes'   => $rd('tx_bytes'),
        'rx_packets' => $rd('rx_packets'),
        'tx_packets' => $rd('tx_packets'),
        'rx_errors'  => $rd('rx_errors'),
        'tx_errors'  => $rd('tx_errors'),
        'rx_dropped' => $rd('rx_dropped'),
        'rx_mb'      => round($rd('rx_bytes') / 1048576, 2),
        'tx_mb'      => round($rd('tx_bytes') / 1048576, 2),
    ];
}

function get_conn(): int {
    $out = trim(shell_exec('ss -tn state established 2>/dev/null | wc -l') ?? '0');
    return max(0, (int)$out - 1); // başlık satırını çıkar
}

function get_top_conn(): array {
    $lines = [];
    exec("ss -tnp state established 2>/dev/null | awk '{print \$5}' | grep -oP '[\d.]+(?=:\d+$)' | sort | uniq -c | sort -rn | head -20", $lines);
    $r = [];
    foreach ($lines as $l) {
        $p = preg_split('/\s+/', trim($l));
        if (count($p) >= 2) $r[] = ['count' => (int)$p[0], 'ip' => $p[1]];
    }
    return $r;
}

function get_ipt_counts(): array {
    // L4 zinciri
    $l4 = ipt('-L EG_L4 -nvx 2>/dev/null') ?: ipt('-L EG_L4_IN -nvx 2>/dev/null');
    // L7 zinciri
    $l7 = ipt('-L EG_L7 -nvx 2>/dev/null') ?: ipt('-L EG_L7_IN -nvx 2>/dev/null');

    $sum = function(array $lines, string $pat): int {
        $t = 0;
        foreach ($lines as $l) {
            if (str_contains($l, $pat)) {
                preg_match('/^\s*(\d+)/', $l, $m);
                $t += (int)($m[1] ?? 0);
            }
        }
        return $t;
    };

    $drop_l4 = ipt('-L EG_L4 -n 2>/dev/null') ?: ipt('-L EG_L4_IN -n 2>/dev/null');
    $blk_rules = count(array_filter($drop_l4, fn($l) => str_starts_with($l, 'DROP')));

    return [
        'l4' => [
            'syn'  => $sum($l4, 'EG-L4-SYN'),
            'udp'  => $sum($l4, 'EG-L4-UDP'),
            'icmp' => $sum($l4, 'EG-L4-ICMP'),
            'rst'  => $sum($l4, 'EG-L4-RST'),
            'xmas' => $sum($l4, 'EG-L4-XMAS'),
            'null' => $sum($l4, 'EG-L4-NULL'),
            'frag' => $sum($l4, 'EG-L4-FRAG'),
            'scan' => $sum($l4, 'EG-L4-SCAN'),
        ],
        'l7' => [
            'http'      => $sum($l7, 'EG-L7-HTTP-'),     // GET + SYN
            'https'     => $sum($l7, 'EG-L7-HTTPS-'),    // GET + SYN
            'ssh'       => $sum($l7, 'EG-SSH-BF'),
            'ftp'       => $sum($l7, 'EG-L7-FTP'),
            'smtp'      => $sum($l7, 'SMTP'),
            'rapidreset' => $sum($l7, 'eg_reset_'),       // RapidReset RST flood
        ],
        'blocked_rules' => $blk_rules,
    ];
}

function get_open_ports(): array {
    $lines = [];
    exec("ss -tlnp 2>/dev/null | awk 'NR>1{print \$4}'", $lines);
    $r = [];
    foreach ($lines as $l) {
        $p = preg_split('/[:\s]+/', trim($l));
        $pt = (int)($p[count($p) - 1] ?? 0);
        if ($pt > 0) $r[] = $pt;
    }
    return array_values(array_unique($r));
}

function get_processes(): array {
    $lines = [];
    exec("ps aux --sort=-%cpu 2>/dev/null | head -11", $lines);
    $r = [];
    foreach (array_slice($lines, 1) as $l) {
        $p = preg_split('/\s+/', trim($l), 11);
        if (count($p) >= 11)
            $r[] = [
                'pid' => $p[1],
                'cpu' => (float)$p[2],
                'mem' => (float)$p[3],
                'cmd' => substr($p[10], 0, 45),
            ];
    }
    return $r;
}

function svc_status(): string {
    $out = [];
    exec('systemctl is-active eagle-guard 2>/dev/null', $out);
    return trim($out[0] ?? 'inactive');
}

function get_unread_count(): int {
    $d = jr(ALRT);
    return count(array_filter($d['alerts'] ?? [], fn($a) => !($a['read'] ?? false)));
}

// ── Router ────────────────────────────────────────────────────────
$action = $_REQUEST['action'] ?? '';

switch ($action) {

    // ── Dashboard (ana veri) ──────────────────────────────────────
    case 'dashboard':
        $stats = jr(STATS);
        ok([
            'service'       => svc_status(),
            'stats'         => $stats,
            'ipt'           => get_ipt_counts(),
            'net'           => get_net(),
            'sys'           => ['cpu' => get_cpu(), 'mem' => get_mem(), 'disk' => get_disk()],
            'alert_unread'  => get_unread_count(),
            'open_ports'    => get_open_ports(),
            'connections'   => get_conn(),
        ]);

    // ── Trafik geçmişi ────────────────────────────────────────────
    case 'traffic':
        $d = jr(TRF);
        ok(array_slice($d['points'] ?? [], -120));

    // ── Anlık veri ────────────────────────────────────────────────
    case 'realtime':
        ok([
            'net'  => get_net(),
            'cpu'  => get_cpu(),
            'mem'  => get_mem(),
            'conn' => get_conn(),
            'ts'   => time(),
        ]);

    // ── Log akışı ─────────────────────────────────────────────────
    case 'logs':
        $n = min((int)($_GET['n'] ?? 100), 500);
        if (!file_exists(LOGF)) { ok([]); break; }
        $lines = [];
        exec('tail -' . $n . ' ' . escapeshellarg(LOGF), $lines);
        $r = [];
        foreach (array_reverse($lines) as $l) {
            if (preg_match('/^\[(.+?)\] \[(.+?)\] (.+)$/', $l, $m))
                $r[] = ['time' => $m[1], 'level' => $m[2], 'msg' => trim($m[3])];
        }
        ok($r);

    // ── WAF Logları ────────────────────────────────────────────────
    case 'waf_logs':
        $n = min((int)($_GET['n'] ?? 100), 500);
        $waf_log = EG . '/waf/logs/audit.log';
        if (!file_exists($waf_log)) { ok([]); break; }
        $lines = [];
        exec('tail -' . $n . ' ' . escapeshellarg($waf_log), $lines);
        $r = [];
        foreach (array_reverse($lines) as $l) {
            if (empty($l)) continue;
            $l = json_decode($l, true) ?: [];
            if (is_array($l) && isset($l['timestamp'])) {
                $r[] = [
                    'time' => $l['timestamp'] ?? date('Y-m-d H:i:s'),
                    'ip' => $l['client_ip'] ?? $l['ip'] ?? '-',
                    'rule' => $l['rule_id'] ?? $l['rule'] ?? 'N/A',
                    'msg' => $l['message'] ?? $l['msg'] ?? 'WAF Event',
                    'action' => stripos($l['action'] ?? 'block', 'block') !== false ? 'block' : 'allow'
                ];
            }
        }
        ok($r);

    // ── Alertler ──────────────────────────────────────────────────
    case 'alerts':
        $d = jr(ALRT);
        ok($d['alerts'] ?? []);

    // ── Alertleri okundu işaretle ─────────────────────────────────
    case 'mark_read':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $d = jr(ALRT);
        foreach ($d['alerts'] as &$a) $a['read'] = true;
        file_put_contents(ALRT, json_encode($d));
        ok(null, 'Okundu işaretlendi');

    // ── Engellenen IP'ler ─────────────────────────────────────────
    case 'blocked':
        $d = jr(BLKD);
        $live = ipt('-L EG_L4 -n 2>/dev/null') ?: ipt('-L EG_L4_IN -n 2>/dev/null');
        $ips = [];
        foreach ($live as $l) {
            if (str_starts_with($l, 'DROP') || str_starts_with($l, 'DROP ')) {
                preg_match('/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/', $l, $m);
                if (!empty($m[1])) $ips[] = $m[1];
            }
        }
        ok(['list' => $d['blocked'] ?? [], 'live' => array_values(array_unique($ips))]);

    // ── Top bağlantılar ───────────────────────────────────────────
    case 'top_conn':
        ok(get_top_conn());

    // ── Süreçler ──────────────────────────────────────────────────
    case 'processes':
        ok(get_processes());

    // ── Sistem bilgisi ────────────────────────────────────────────
    case 'sysinfo':
        ok([
            'cpu'        => get_cpu(),
            'mem'        => get_mem(),
            'disk'       => get_disk(),
            'net'        => get_net(),
            'open_ports' => get_open_ports(),
            'hostname'   => gethostname(),
            'uptime'     => trim(shell_exec('uptime -p 2>/dev/null') ?? ''),
            'os'         => trim(shell_exec('lsb_release -ds 2>/dev/null') ?? 'Linux'),
        ]);

    // ── iptables L4 kuralları ─────────────────────────────────────
    case 'ipt_l4': {
        $lines = ipt('-L EG_L4 -nvx') ?: ipt('-L EG_GUARD -nvx');
        $joined = implode("\n", $lines);
        if (empty($lines) || stripos($joined,'incompatible')!==false || stripos($joined,'nf_tables')!==false) {
            $r = run('sudo iptables -L EG_L4 -nvx 2>&1');
            $lines = $r['out'];
        }
        ok($lines);
    }

    // ── iptables L7 kuralları ─────────────────────────────────────
    case 'ipt_l7': {
        $lines = ipt('-L EG_L7 -nvx') ?: ipt('-L EG_GUARD -nvx');
        $joined = implode("\n", $lines);
        if (empty($lines) || stripos($joined,'incompatible')!==false || stripos($joined,'nf_tables')!==false) {
            $r = run('sudo iptables -L EG_L7 -nvx 2>&1');
            $lines = $r['out'];
        }
        ok($lines);
    }

    // ── Servis başlat ─────────────────────────────────────────────
    case 'start':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $r = run('start');
        // systemctl start de paralel dene (ExecStartPre XDP vs. hook'ları için)
        $sysc = []; exec('sudo -n systemctl start eagle-guard 2>&1', $sysc);
        $r['out'] = array_merge($r['out'], ['── systemctl ──'], $sysc);
        if ($r['code'] !== 0) fail('Başlatılamadı (rc='.$r['code'].'): ' . implode(' | ', array_slice($r['out'],-10)), 500);
        ok(['out' => $r['out'], 'code' => $r['code'], 'exit_code' => $r['code']], 'Başlatıldı');

    // ── Servis durdur ─────────────────────────────────────────────
    case 'stop':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $r = run('stop');
        $sysc = []; exec('sudo -n systemctl stop eagle-guard 2>&1', $sysc);
        $r['out'] = array_merge($r['out'], ['── systemctl ──'], $sysc);
        ok(['out' => $r['out'], 'code' => $r['code'], 'exit_code' => $r['code']], 'Durduruldu');

    // ── Servis yeniden başlat ─────────────────────────────────────
    case 'restart':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        // Arka planda çalıştır — HTTP cevap dönebilsin (restart sırasında Apache donmasın)
        $cmd = 'sudo ' . escapeshellarg(BIN) . ' restart > /tmp/eagle-restart.log 2>&1 &';
        exec($cmd);
        ok(null, 'Yeniden başlatma tetiklendi — 2-3 saniye içinde aktif olur');

    // ── Webhook / bildirim testi (Discord/Telegram/Email) ─────────
    case 'webhook_test':
    case 'test_notify':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $r = run('test-notify');
        // Alert JSON'a da yazalım ki UI'da görünsün
        $d = jr(ALRT);
        array_unshift($d['alerts'], [
            'type'=>'system','title'=>'🧪 Bildirim Testi',
            'detail'=>'Web arayüzünden tetiklendi — Discord/Telegram/Email kanallarına gönderildi',
            'severity'=>'low','time'=>date('c'),'read'=>false,
        ]);
        $d['alerts'] = array_slice($d['alerts'],0,200);
        @file_put_contents(ALRT, json_encode($d));
        ok(['out'=>$r['out'],'code'=>$r['code']], 'Bildirim testi gönderildi');

    // ── IP engelle ────────────────────────────────────────────────
    case 'block':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $ip    = trim($_POST['ip'] ?? '');
        $layer = preg_replace('/[^A-Z0-9]/', '', strtoupper($_POST['layer'] ?? 'L4'));
        if (!valid_ip($ip)) fail('Geçersiz IP adresi');
        // Whitelist kontrolü
        if (file_exists(WL)) {
            $wl = array_map('trim', file(WL));
            if (in_array($ip, $wl)) fail("$ip whitelist'te, engellenemez");
        }
        $r = run("block " . escapeshellarg($ip) . " manual $layer");
        ok(['ip' => $ip], "Engellendi: $ip");

    // ── IP engel kaldır ───────────────────────────────────────────
    case 'unblock':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $ip = trim($_POST['ip'] ?? '');
        if (!valid_ip($ip)) fail('Geçersiz IP');
        $r = run("unblock " . escapeshellarg($ip));
        ok(['ip' => $ip], "Engel kaldırıldı: $ip");

    // ── Konfigürasyon oku ─────────────────────────────────────────
    case 'config':
        if (!file_exists(CONF)) fail('Config bulunamadı', 404);
        $cfg = [];
        foreach (file(CONF) as $line) {
            $line = trim($line);
            if (!$line || $line[0] === '#') continue;
            if (str_contains($line, '=')) {
                [$k, $v] = explode('=', $line, 2);
                $cfg[trim($k)] = trim($v);
            }
        }
        ok($cfg);

    // ── Konfigürasyon kaydet (v7.2: merge, mevcut config korunur) ──────
    case 'save_config':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        // UI alias → canonical eagle.conf anahtarları (geriye dönük destek)
        $alias = [
            'L4_SYN'       => 'L4_SYN_RATE',
            'L4_SYN_B'     => 'L4_SYN_BURST',
            'L4_ICMP'      => 'L4_ICMP_RATE',
            'L4_RATE'      => 'L4_SYN_PER_IP',
            'L4_CONN'      => 'L4_CONN_PER_IP',
            'L7_HTTP_RPS'  => 'L7_HTTP_RATE',
            'L7_HTTP_CONN' => 'L7_HTTP_CONN',
            'L7_SSH'       => 'L7_SSH_RATE',
            'A_PPS'        => 'ALERT_PPS',
            'A_BPS'        => 'ALERT_BPS',
            'A_CONN'       => 'ALERT_CONN',
            'BAN'          => 'BAN_TIME',
            'INTERVAL'     => 'INTERVAL',
            'AUTO'         => 'AUTO_BLOCK',
            'WEBHOOK'      => 'DISCORD_WEBHOOK',
            'EMAIL'        => 'EMAIL_TO',
            'TG_BOT'       => 'TELEGRAM_BOT',
            'TG_CHAT'      => 'TELEGRAM_CHAT',
        ];
        $canonical = [
            'L4_SYN_RATE','L4_SYN_BURST','L4_ICMP_RATE','L4_SYN_PER_IP','L4_CONN_PER_IP',
            'L7_HTTP_CONN','L7_HTTP_RATE','L7_SSH_RATE',
            'NGINX_ENABLED','NGINX_REQ_RATE','NGINX_BURST','NGINX_CONN_PER_IP',
            'F2B_ENABLED','F2B_SSH_MAXRETRY','F2B_SSH_BANTIME',
            'F2B_HTTP_MAXRETRY','F2B_HTTP_BANTIME','F2B_FINDTIME',
            'GAME_ENABLED','GAME_UDP_PPS','GAME_UDP_BURST','GAME_TCP_CONN',
            'GAME_PORTS_UDP','GAME_PORTS_TCP',
            'ALERT_PPS','ALERT_BPS','ALERT_CONN','BAN_TIME','INTERVAL',
            'AUTO_BLOCK','AUTOBLOCK_HITS',
            'DISCORD_WEBHOOK','TELEGRAM_BOT','TELEGRAM_CHAT','EMAIL_TO',
            'REPORT_ENABLED','REPORT_INTERVAL',
            'XDP_ENABLED','XDP_IFACE','XDP_MODE','XDP_PPS_LIMIT','XDP_SYN_LIMIT',
            'ADMIN_PORT_SSH','ADMIN_PORT_WEB','ADMIN_PORT_WEB2',
            'DPDK_ENABLED','DPDK_IFACE','DPDK_DRIVER','DPDK_HUGEPAGES',
        ];
        $valid = array_flip($canonical);

        $updates = [];
        foreach ($_POST as $k => $v) {
            if ($k === 'action') continue;
            $ck = $alias[$k] ?? $k;
            if (!isset($valid[$ck])) continue;
            $v = is_string($v) ? $v : '';
            // Tehlikeli karakterleri temizle; webhook URL'leri, virgüllü port listeleri OK
            $v = str_replace(["\r","\n","\"","'","`","\\"], '', $v);
            $v = trim($v);
            $updates[$ck] = $v;
        }

        // Mevcut dosyayı satır satır işle — koru + güncelle
        $existing = file_exists(CONF) ? file(CONF) : [];
        $out_lines = [];  $seen = [];
        foreach ($existing as $ln) {
            $t = rtrim($ln, "\r\n");
            if ($t === '' || $t[0] === '#' || !str_contains($t, '=')) {
                $out_lines[] = $ln;  continue;
            }
            [$k] = explode('=', $t, 2);
            $k = trim($k);
            if (array_key_exists($k, $updates)) {
                $out_lines[] = $k . '=' . $updates[$k] . "\n";
                $seen[$k] = true;
            } else {
                $out_lines[] = $ln;
            }
        }
        foreach ($updates as $k => $v) {
            if (empty($seen[$k])) $out_lines[] = $k . '=' . $v . "\n";
        }

        $tmp = CONF . '.tmp.' . getmypid();
        if (file_put_contents($tmp, implode('', $out_lines)) === false || !@rename($tmp, CONF)) {
            @unlink($tmp);
            fail('Config kaydedilemedi — izin sorunu (www-data yazma hakkı?)');
        }
        @chmod(CONF, 0644);
        ok(['updated' => array_keys($updates), 'count' => count($updates)],
           'Kaydedildi (' . count($updates) . ' alan güncellendi)');

    // ── Whitelist ─────────────────────────────────────────────────
    case 'whitelist':
        $ips = file_exists(WL)
            ? array_values(array_filter(array_map('trim', file(WL))))
            : [];
        ok($ips);

    case 'wl_add':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $ip = trim($_POST['ip'] ?? '');
        if (!valid_ip($ip)) fail('Geçersiz IP');
        $existing = file_exists(WL) ? array_map('trim', file(WL)) : [];
        if (!in_array($ip, $existing))
            file_put_contents(WL, "$ip\n", FILE_APPEND);
        ok(null, "Eklendi: $ip");

    case 'wl_remove':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $ip  = trim($_POST['ip'] ?? '');
        $ips = file_exists(WL) ? array_map('trim', file(WL)) : [];
        $ips = array_filter($ips, fn($x) => $x && $x !== $ip);
        file_put_contents(WL, implode("\n", $ips) . "\n");
        ok(null, "Kaldırıldı: $ip");

    // ── Test alert (hem JSON'a yaz hem de gerçek Discord/Telegram tetikle) ──
    case 'test_alert':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $d = jr(ALRT);
        array_unshift($d['alerts'], [
            'type'     => 'system',
            'title'    => '🧪 Test Alert',
            'detail'   => 'Web arayüzünden manuel test — ' . date('H:i:s'),
            'severity' => 'low',
            'time'     => date('c'),
            'read'     => false,
        ]);
        $d['alerts'] = array_slice($d['alerts'], 0, 200);
        @file_put_contents(ALRT, json_encode($d));
        // Gerçek bildirim
        $r = run('test-notify');
        ok(['out'=>$r['out'], 'code'=>$r['code']],
           'Test alert JSON\'a yazıldı ve Discord/Telegram tetiklendi');

    // ── Debug (geliştirme) ────────────────────────────────────────
    case 'debug':
        ok([
            'eg_dir_exists'  => is_dir(EG),
            'stats_exists'   => file_exists(STATS),
            'bin_exists'     => file_exists(BIN),
            'bin_executable' => is_executable(BIN),
            'data_writable'  => is_writable(EG . '/data'),
            'logs_readable'  => is_readable(EG . '/logs'),
            'conf_exists'    => file_exists(CONF),
            'wl_exists'      => file_exists(WL),
            'php_version'    => PHP_VERSION,
            'server_user'    => trim(shell_exec('whoami') ?? ''),
            'sudo_test'      => trim(shell_exec('sudo -l 2>&1 | head -5') ?? ''),
        ]);



    // ── Game Layer kuralları ──────────────────────────────────────────
    case 'ipt_game': {
        $lines = ipt('-L EG_GAME -nvx');
        $joined = implode("\n", $lines);
        if (empty($lines) || stripos($joined,'incompatible')!==false || stripos($joined,'nf_tables')!==false) {
            $r = run('rules-game');
            $lines = $r['out'];
        }
        ok($lines);
    }

    // ── Game aç ──────────────────────────────────────────────────────
    case 'game_on':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $r = run('game-on');
        ok(['out' => $r['out']], 'Game koruması açıldı');

    // ── Game kapat ────────────────────────────────────────────────────
    case 'game_off':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $r = run('game-off');
        ok(['out' => $r['out']], 'Game koruması kapatıldı');

    // ── Game istatistikleri ───────────────────────────────────────────
    case 'game_stats':
        $st = jr(STATS);
        $game = $st['game'] ?? [];
        // EG_GAME chain sayaçları
        $gl = ipt('-L EG_GAME -nvx 2>/dev/null');
        $sum = function(array $lines, string $pat): int {
            $t = 0;
            foreach ($lines as $l) {
                if (str_contains($l, $pat)) {
                    preg_match('/^\s*(\d+)/', $l, $m);
                    $t += (int)($m[1] ?? 0);
                }
            }
            return $t;
        };
        ok([
            'from_stats'  => $game,
            'udp_flood'   => $sum($gl, 'GAME-UDP-FLOOD'),
            'tcp_flood'   => $sum($gl, 'GAME-TCP-FLOOD'),
            'query_flood' => $sum($gl, 'GAME-QUERY'),
            'fake_conn'   => $sum($gl, 'GAME-FAKECON'),
            'rcon'        => $sum($gl, 'GAME-RCON'),
            'oversized'   => $sum($gl, 'GAME-OVERSIZED'),
            'amplify'     => $sum($gl, 'GAME-AMPLIFY'),
            'tiny_udp'    => $sum($gl, 'GAME-TINY'),
            'fivem'       => $sum($gl, 'GAME-FIVEM'),
            'ts3'         => $sum($gl, 'GAME-TS3'),
            'mc_ping'     => $sum($gl, 'GAME-MC-PING'),
            'src_query'   => $sum($gl, 'GAME-AMPLIFY'),
        ]);

    // ── Terminal komut çalıştır ─────────────────────────────────────
    case 'exec_cmd':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $cmd = trim($_POST['cmd'] ?? '');
        if (empty($cmd)) fail('Komut boş');

        // Yasaklı pattern'ler
        $blocked_patterns = [
            '/rm\s/', '/\brm\b/', '/\bmv\b/', '/chmod/', '/chown/',
            '/passwd/', '/useradd/', '/shutdown/', '/reboot/',
            '/mkfs/', '/\bdd\b/', '/kill\s/', '/pkill/',
        ];
        foreach ($blocked_patterns as $pat) {
            if (@preg_match($pat, $cmd)) {
                fail('Güvenlik: Bu komut kısıtlanmıştır');
            }
        }
        if (preg_match('/curl.*\|.*bash/i', $cmd) || preg_match('/wget.*\|.*sh/i', $cmd)) {
            fail('Güvenlik: Pipe ile shell çalıştırma yasak');
        }

        // İzin verilen komutlar (prefix eşleşir)
        $allowed = [
            'eagle-guard', 'iptables', 'ip6tables', 'nft', 'ipset',
            'ss', 'netstat', 'ip ', 'ip6 ',
            'systemctl status eagle-guard', 'systemctl is-active',
            'systemctl start eagle-guard', 'systemctl stop eagle-guard',
            'systemctl restart eagle-guard', 'systemctl reload eagle-guard',
            'journalctl -u eagle-guard', 'journalctl',
            'df', 'free', 'uptime', 'uname', 'hostname', 'whoami', 'id',
            'cat /opt/eagle-guard/', 'cat /etc/eagle', 'cat /proc/',
            'tail', 'head', 'ls', 'wc', 'grep', 'awk', 'sort', 'uniq',
            'ps', 'top -bn1', 'ping -c', 'traceroute', 'dig', 'nslookup',
            'curl -s', 'curl -v', 'curl -I', 'curl --',
            'python3 -m json', 'bpftool', 'ethtool',
            'fail2ban-client', 'nginx -t', 'nginx -T',
        ];
        $cmdLower = strtolower(trim($cmd));
        // "sudo " öneki varsa kaldır — zaten ekleyeceğiz
        $cmdStripped = preg_replace('/^sudo\s+/i', '', $cmd);
        $stripLower  = strtolower($cmdStripped);
        $isAllowed = false;
        foreach ($allowed as $a) {
            if (str_starts_with($stripLower, strtolower(trim($a)))) {
                $isAllowed = true; break;
            }
        }
        if (!$isAllowed) { fail('İzin verilmedi: Komut politika dışında'); }

        // eagle-guard komutunu BIN ile çalıştır; diğerlerinde root yetkisi için sudo
        if (str_starts_with($stripLower, 'eagle-guard ')) {
            $args = substr($cmdStripped, strlen('eagle-guard '));
            $safecmd = 'sudo -n ' . escapeshellarg(BIN) . ' ' . $args . ' 2>&1';
        } elseif (trim($stripLower) === 'eagle-guard') {
            $safecmd = 'sudo -n ' . escapeshellarg(BIN) . ' 2>&1';
        } else {
            // Diğer tüm komutlar sudo ile çalışsın (iptables, systemctl, journalctl, ss -p vb.)
            $safecmd = 'sudo -n ' . $cmdStripped . ' 2>&1';
        }

        $output = []; $code = 0;
        exec($safecmd, $output, $code);
        // Status satırı ekle — UI'da gözüksün
        $output[] = '';
        $output[] = '── exit code: ' . $code . ' ──';
        ok(['output' => $output, 'code' => $code, 'exit_code' => $code, 'cmd' => $cmdStripped]);

    // ── XDP / eBPF durum ──────────────────────────────────────────
    case 'xdp_status':
        $r = ['available' => false, 'attached' => false, 'iface' => null, 'mode' => null, 'stats' => []];
        $r['available'] = is_executable('/opt/eagle-guard/xdp/eagle-xdp-loader.sh')
                          && file_exists('/opt/eagle-guard/xdp/eagle_xdp.o');
        $iface = @trim(@file_get_contents('/sys/fs/bpf/eagle/.iface') ?: '');
        if ($iface !== '') {
            $r['iface'] = $iface;
            $link = [];
            exec('ip link show ' . escapeshellarg($iface) . ' 2>/dev/null', $link);
            foreach ($link as $l) {
                if (preg_match('/xdp(generic|drv|offload)/', $l, $m)) {
                    $r['attached'] = true;
                    $r['mode'] = $m[1];
                }
            }
        }
        // İstatistik map dump (best-effort)
        if (is_readable('/sys/fs/bpf/eagle/stats')) {
            $out = []; exec('sudo bpftool map dump pinned /sys/fs/bpf/eagle/stats 2>/dev/null', $out);
            $labels = ['PASS','DROP_BLACKLIST','DROP_RATELIMIT','DROP_MALFORMED',
                       'PASS_SSH','PASS_WEB','PASS_WHITELIST','DROP_HARDBAN'];
            foreach ($labels as $i => $lbl) $r['stats'][$lbl] = 0;
            // parse text format (basit)
            $cur = null;
            foreach ($out as $line) {
                if (preg_match('/key:\s+([0-9a-f ]+)/i', $line, $m)) {
                    $b = preg_split('/\s+/', trim($m[1]));
                    $cur = isset($b[0]) ? hexdec($b[0]) : null;
                } elseif ($cur !== null && preg_match('/value:\s+([0-9a-f ]+)/i', $line, $m)) {
                    $vb = preg_split('/\s+/', trim($m[1]));
                    // per-cpu: ilk 8 byte bir CPU; toplam için tümünü topla
                    $sum = 0; $chunks = array_chunk($vb, 8);
                    foreach ($chunks as $c) {
                        if (count($c) < 8) continue;
                        $sum += hexdec($c[7].$c[6].$c[5].$c[4].$c[3].$c[2].$c[1].$c[0]);
                    }
                    if (isset($labels[$cur])) $r['stats'][$labels[$cur]] = $sum;
                    $cur = null;
                }
            }
        }
        ok($r);

    // ── XDP başlat/durdur ─────────────────────────────────────────
    case 'xdp_load':
    case 'xdp_unload':
    case 'xdp_reload':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST gerekli', 405);
        $sub = substr($action, 4); // load|unload|reload
        $out = []; $rc = 0;
        exec('sudo /opt/eagle-guard/xdp/eagle-xdp-loader.sh ' . escapeshellarg($sub) . ' 2>&1', $out, $rc);
        ok(['output' => $out, 'code' => $rc]);

    // ── DPDK durum ────────────────────────────────────────────────
    case 'dpdk_status':
        $r = ['available' => false, 'mgmt_iface' => null, 'output' => []];
        $r['available'] = is_executable('/opt/eagle-guard/dpdk/eagle-dpdk-setup.sh')
                          && trim(shell_exec('command -v dpdk-devbind.py 2>/dev/null')) !== '';
        $r['mgmt_iface'] = trim(shell_exec("ip -o route show default 2>/dev/null | awk '{print \$5; exit}'"));
        if ($r['available']) {
            exec('sudo /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh status 2>&1', $r['output']);
        }
        ok($r);

    default:
        fail('Bilinmeyen action: ' . htmlspecialchars($action, ENT_QUOTES));
}
