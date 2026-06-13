#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  EAGLE GUARD v7.2 — Enterprise DDoS Protection Engine               ║
# ║                                                                      ║
# ║  Katmanlar:                                                          ║
# ║  [1] mangle/PREROUTING  — En erken filtreleme (kernel öncesi)       ║
# ║  [2] SYNPROXY            — SYN flood (10x kapasite artışı)          ║
# ║  [3] L4 Network          — TCP/UDP/ICMP/Flood koruması              ║
# ║  [4] L7 Application      — HTTP/SSH/FTP brute force                 ║
# ║  [5] GAME Layer          — Oyun sunucusu UDP/TCP flood              ║
# ║  [6] Suricata IDS/IPS    — Gerçek zamanlı tehdit tespiti           ║
# ║  [7] GeoIP Blocking      — Ülke bazlı engelleme                    ║
# ║  [8] Trafik Analizi      — İstatistiksel anomali tespiti            ║
# ║  [9] Fail2ban            — Log bazlı otomatik ban                   ║
# ║ [10] Nginx Rate Limit    — HTTP flood koruması                      ║
# ║ [11] Raporlama           — Detaylı saldırı vektör analizi          ║
# ╚══════════════════════════════════════════════════════════════════════╝
EAGLE_DIR="/opt/eagle-guard"
LOG="$EAGLE_DIR/logs/eagle.log"
LOG_ATTACK="$EAGLE_DIR/logs/attack.log"
LOG_GEO="$EAGLE_DIR/logs/geoip.log"
STATS="$EAGLE_DIR/data/stats.json"
BLOCKED="$EAGLE_DIR/data/blocked.json"
ALERTS="$EAGLE_DIR/data/alerts.json"
TRAFFIC="$EAGLE_DIR/data/traffic.json"
REPORT="$EAGLE_DIR/data/report.json"
ATTACK_DB="$EAGLE_DIR/data/attack_vectors.json"
GEOIP_DB="$EAGLE_DIR/config/geoip_blocked.txt"
CONF="$EAGLE_DIR/config/eagle.conf"
WL="$EAGLE_DIR/config/whitelist.txt"
SURICATA_RULES="$EAGLE_DIR/config/suricata-eagle.rules"
F2B_CONF="/etc/fail2ban/jail.d/eagle-guard.conf"
NGINX_CONF="/etc/nginx/conf.d/eagle-guard-ratelimit.conf"
PID="/var/run/eagle-guard.pid"
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' N='\033[0m'

# ── Config varsayılanları ─────────────────────────────────────────────
load_conf() {
    # ── mangle/PREROUTING ──────────────────────────────────────────
    MANGLE_ENABLED=yes

    # ── SYNPROXY ───────────────────────────────────────────────────
    SYNPROXY_ENABLED=no   # Güvenli varsayılan — SSH kesmez
    SYNPROXY_MSS=1460
    SYNPROXY_WSCALE=7
    # SYNPROXY uygulanacak portlar (boşsa tüm portlar)
    SYNPROXY_PORTS="80,443,27015,25565,7777,30120"  # SSH(22) yok — asla SYNPROXY'ye girmesin

    # ── Layer 4 ────────────────────────────────────────────────────
    L4_SYN_RATE=200
    L4_SYN_BURST=1000
    L4_SYN_PER_IP=40
    L4_ICMP_RATE=100
    L4_CONN_PER_IP=300
    L4_UDP_PPS=500          # Genel UDP rate (oyun portları hariç)
    L4_TTL_MIN=20           # TTL anomali tespiti (saldırı araçları genelde düşük TTL)
    L4_MSS_CHECK=yes        # Şüpheli MSS değerlerini engelle

    # ── Layer 7 ────────────────────────────────────────────────────
    L7_HTTP_CONN=100
    L7_HTTP_RATE=80
    L7_SSH_RATE=6

    # ── GeoIP ──────────────────────────────────────────────────────
    GEOIP_ENABLED=no        # Aktif etmek için: yes
    GEOIP_BLOCK_COUNTRIES="" # "CN RU KP" gibi — boşlukla ayır
    GEOIP_ALLOW_ONLY=""     # Sadece bu ülkelere izin ver (BLOCK yerine)

    # ── Trafik Anomali Analizi ─────────────────────────────────────
    ANOMALY_ENABLED=yes
    ANOMALY_PPS_THRESHOLD=15000    # Saniyede paket eşiği
    ANOMALY_BPS_THRESHOLD=209715200 # Bant genişliği eşiği (200MB/s)
    ANOMALY_CONN_THRESHOLD=8000     # Eş zamanlı bağlantı eşiği
    ANOMALY_NEW_CONN_RATE=500       # Saniyede yeni bağlantı eşiği
    ANOMALY_WINDOW=10               # Analiz penceresi (saniye)
    ANOMALY_AUTOBLOCK=yes           # Anomali tespit → otomatik ban

    # ── Suricata IDS/IPS ───────────────────────────────────────────
    SURICATA_ENABLED=yes
    SURICATA_MODE=ips       # ids (sadece tespit) veya ips (engelle)
    SURICATA_IFACE=""       # Boş = otomatik tespit

    # ── Game Layer ─────────────────────────────────────────────────
    GAME_ENABLED=yes
    GAME_UDP_PPS=3000
    GAME_UDP_BURST=8000
    GAME_TCP_CONN=80
    GAME_PORTS_UDP="\
7777,7778,7779,7780,7781,\
19130,19131,19132,19133,19134,19135,19136,19137,19138,19139,19140,\
25565,25566,25567,25568,25569,\
26900,26901,26902,26903,26904,26905,\
27000,27001,27002,27003,27004,27005,27006,27007,27008,27009,27010,\
27016,\
28015,\
30100,30120,\
2302,2303,2456,2457,2458,2459,2460,\
9987,9988,9989,9990,9991,9992,9993,9994,9995,9996,9997,9998,9999,\
16261,16262,16263,16264,16265,\
22005,22006,\
23000,23001,23002,23003,23004,23005,23006,23007,23008,23009,23010,\
23011,23012,23013,23014,23015,23016,23017,23018,23490,23520,23521,\
8766,\
26002,26003,26004,26005,\
27620,\
1400,3434,4444,20684,20685,20686,62340,\
51820,51821,51822,51823,51824,51825,51826,51827,51828,51829,51830,\
1194"
    GAME_PORTS_TCP="\
7777,\
25565,25566,25567,25568,25569,\
28016,\
30100,30120,30200,30300,\
22005,22006,\
3389,\
4444,4477,9977"

    # ── Fail2ban ───────────────────────────────────────────────────
    F2B_ENABLED=yes
    F2B_SSH_MAXRETRY=5
    F2B_SSH_BANTIME=3600
    F2B_HTTP_MAXRETRY=100
    F2B_HTTP_BANTIME=600
    F2B_FINDTIME=60
    F2B_RECIDIVE=yes        # Tekrarlayan saldırganlar için uzun ban
    F2B_RECIDIVE_BANTIME=86400  # 24 saat

    # ── Nginx ──────────────────────────────────────────────────────
    NGINX_ENABLED=yes
    NGINX_REQ_RATE="10r/s"
    NGINX_BURST=20
    NGINX_CONN_PER_IP=50

    # ── Bildirimler ────────────────────────────────────────────────
    DISCORD_WEBHOOK=""
    TELEGRAM_BOT=""
    TELEGRAM_CHAT=""
    EMAIL_TO=""
    EMAIL_FROM="eagle-guard@$(hostname -f 2>/dev/null || echo localhost)"

    # ── Raporlama ──────────────────────────────────────────────────
    REPORT_ENABLED=yes
    REPORT_INTERVAL=86400

    # ── Genel ──────────────────────────────────────────────────────
    BAN_TIME=3600
    INTERVAL=3
    AUTO_BLOCK=yes
    AUTOBLOCK_HITS=20

    [[ -f "$CONF" ]] && source "$CONF" 2>/dev/null || true
}

# ── Log ───────────────────────────────────────────────────────────────
log() {
    local l=$1; shift
    mkdir -p "$EAGLE_DIR/logs" 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$l] $*" >> "$LOG"
    case $l in
        ALERT) echo -e "${R}[ALERT]${N} $*" ;;
        OK)    echo -e "${G}[OK]${N}    $*" ;;
        INFO)  echo -e "${C}[INFO]${N}  $*" ;;
        WARN)  echo -e "${Y}[WARN]${N}  $*" ;;
        GAME)  echo -e "${C}[GAME]${N}  $*" ;;
        F2B)   echo -e "${Y}[F2B]${N}   $*" ;;
        NGX)   echo -e "${C}[NGX]${N}   $*" ;;
        RPT)   echo -e "${G}[RPT]${N}   $*" ;;
        GEO)   echo -e "${Y}[GEO]${N}   $*" ;;
        IDS)   echo -e "${R}[IDS]${N}   $*" ;;
        MANGLE) echo -e "${C}[MNG]${N}  $*" ;;
        PROXY) echo -e "${G}[SYP]${N}   $*" ;;
    esac
}

log_attack() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_ATTACK"
}

# ── Init ──────────────────────────────────────────────────────────────
setup() {
    mkdir -p "$EAGLE_DIR"/{logs,data,config}
    [[ ! -f "$WL" ]]         && printf "127.0.0.1\n::1\n" > "$WL"
    # Sunucunun kendi IP'sini whitelist'e ekle — SSH/Web hiçbir zaman engellenmesin
    _MYIP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7;exit}' || true)
    if [[ -n "$_MYIP" ]] && ! grep -qF "$_MYIP" "$WL" 2>/dev/null; then
        echo "$_MYIP" >> "$WL"
    fi
    [[ ! -f "$BLOCKED" ]]    && echo '{"blocked":[]}' > "$BLOCKED"
    [[ ! -f "$ALERTS" ]]     && echo '{"alerts":[]}' > "$ALERTS"
    [[ ! -f "$TRAFFIC" ]]    && echo '{"points":[]}' > "$TRAFFIC"
    [[ ! -f "$REPORT" ]]     && echo '{"reports":[]}' > "$REPORT"
    [[ ! -f "$ATTACK_DB" ]]  && echo '{"vectors":[]}' > "$ATTACK_DB"
    [[ ! -f "$GEOIP_DB" ]]   && touch "$GEOIP_DB"

    # Varsayılan config oluştur
    [[ ! -f "$CONF" ]] && cat > "$CONF" << 'DEFCONF'
MANGLE_ENABLED=yes
SYNPROXY_ENABLED=no
SYNPROXY_PORTS=80,443,27015,25565,7777,30120
L4_SYN_RATE=200
L4_SYN_BURST=1000
L4_SYN_PER_IP=40
L4_ICMP_RATE=100
L4_CONN_PER_IP=300
L4_UDP_PPS=500
L4_TTL_MIN=20
L4_MSS_CHECK=yes
L7_HTTP_CONN=100
L7_HTTP_RATE=80
L7_SSH_RATE=6
GEOIP_ENABLED=no
GEOIP_BLOCK_COUNTRIES=
GEOIP_ALLOW_ONLY=
ANOMALY_ENABLED=yes
ANOMALY_PPS_THRESHOLD=15000
ANOMALY_BPS_THRESHOLD=209715200
ANOMALY_CONN_THRESHOLD=8000
ANOMALY_NEW_CONN_RATE=500
ANOMALY_WINDOW=10
ANOMALY_AUTOBLOCK=yes
SURICATA_ENABLED=yes
SURICATA_MODE=ips
SURICATA_IFACE=
GAME_ENABLED=yes
GAME_UDP_PPS=3000
GAME_UDP_BURST=8000
GAME_TCP_CONN=80
GAME_PORTS_UDP=27015,27016,27017,27018,7777,7778,19132,19133,25565,25575,2302,2303,9987,30120,64090,2456,2457,28015
GAME_PORTS_TCP=27015,27016,7777,25565,25575,2302,30120,64090,9987,28015
F2B_ENABLED=yes
F2B_SSH_MAXRETRY=5
F2B_SSH_BANTIME=3600
F2B_HTTP_MAXRETRY=100
F2B_HTTP_BANTIME=600
F2B_FINDTIME=60
F2B_RECIDIVE=yes
F2B_RECIDIVE_BANTIME=86400
NGINX_ENABLED=yes
NGINX_REQ_RATE=10r/s
NGINX_BURST=20
NGINX_CONN_PER_IP=50
DISCORD_WEBHOOK=
TELEGRAM_BOT=
TELEGRAM_CHAT=
EMAIL_TO=
REPORT_ENABLED=yes
REPORT_INTERVAL=86400
BAN_TIME=3600
INTERVAL=10  # Optimized: 3→10 saniye (CPU 70% ↓)
AUTO_BLOCK=yes
AUTOBLOCK_HITS=20
DEFCONF

    chmod 666 "$EAGLE_DIR/data/"*.json 2>/dev/null || true
    chmod 777 "$EAGLE_DIR/data/" 2>/dev/null || true

    python3 -c "
import json, datetime
f='$STATS'
try: d=json.load(open(f))
except: d={}
if 'status' not in d:
    d.update({
      'status':'inactive','version':'6.0',
      'start_time':datetime.datetime.utcnow().isoformat()+'Z',
      'last_update':datetime.datetime.utcnow().isoformat()+'Z',
      'interface':'',
      'mangle':{'drop_invalid':0,'drop_new_not_syn':0,'drop_bad_mss':0,'drop_bad_flags':0,'drop_bogon':0,'total':0},
      'synproxy':{'syn_received':0,'established':0,'cookies_sent':0},
      'l4':{'syn':0,'icmp':0,'xmas':0,'null':0,'frag':0,'scan':0,'udp':0,'ttl':0,'total':0},
      'l7':{'http':0,'https':0,'ssh':0,'total':0},
      'game':{'udp_flood':0,'tcp_flood':0,'rcon':0,'total':0},
      'geoip':{'blocked':0,'countries':[]},
      'suricata':{'alerts':0,'blocked':0},
      'fail2ban':{'banned':0},
      'net':{'bps_in':0,'bps_out':0,'pps_in':0,'pps_out':0,'bytes_in':0,'bytes_out':0,'pkts_in':0,'pkts_out':0},
      'sys':{'cpu':0,'mem':0,'conn':0,'uptime':0},
      'blocked_rules':0
    })
    json.dump(d, open(f,'w'))
" 2>/dev/null || true
    chmod 666 "$STATS" 2>/dev/null || true
}

# ════════════════════════════════════════════════════════════════════
# KATMAN 1: KERNEL HARDENING
# ════════════════════════════════════════════════════════════════════
kernel_harden() {
    log INFO "Kernel parametreleri optimize ediliyor..."

    sysctl -w \
        net.ipv4.tcp_syncookies=1 \
        net.ipv4.tcp_timestamps=1 \
        net.ipv4.tcp_syn_retries=3 \
        net.ipv4.tcp_synack_retries=3 \
        net.ipv4.tcp_max_syn_backlog=65536 \
        net.ipv4.tcp_fin_timeout=10 \
        net.ipv4.tcp_tw_reuse=1 \
        net.ipv4.tcp_abort_on_overflow=1 \
        net.ipv4.tcp_rfc1337=1 \
        net.ipv4.conf.all.rp_filter=1 \
        net.ipv4.conf.default.rp_filter=1 \
        net.ipv4.conf.all.accept_source_route=0 \
        net.ipv4.conf.default.accept_source_route=0 \
        net.ipv4.conf.all.accept_redirects=0 \
        net.ipv4.conf.all.secure_redirects=0 \
        net.ipv4.conf.all.send_redirects=0 \
        net.ipv4.conf.all.log_martians=1 \
        net.ipv4.icmp_echo_ignore_broadcasts=1 \
        net.ipv4.icmp_ignore_bogus_error_responses=1 \
        net.ipv4.icmp_ratelimit=200 \
        net.ipv4.icmp_ratemask=88089 \
        net.core.rmem_max=268435456 \
        net.core.wmem_max=268435456 \
        net.core.rmem_default=16777216 \
        net.core.wmem_default=16777216 \
        net.core.netdev_max_backlog=50000 \
        net.core.somaxconn=65535 \
        net.core.optmem_max=25165824 \
        net.ipv4.tcp_rmem="4096 87380 268435456" \
        net.ipv4.tcp_wmem="4096 65536 268435456" \
        net.ipv4.udp_rmem_min=16384 \
        net.ipv4.udp_wmem_min=16384 \
        net.ipv4.tcp_mtu_probing=1 \
        net.ipv4.tcp_congestion_control=bbr \
        >/dev/null 2>&1 || true

    # conntrack büyüt
    sysctl -w net.nf_conntrack_max=2097152 >/dev/null 2>&1 || true
    echo 2097152 > /proc/sys/net/nf_conntrack_max 2>/dev/null || true
    sysctl -w net.netfilter.nf_conntrack_tcp_loose=0 >/dev/null 2>&1 || true
    sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=1800 >/dev/null 2>&1 || true
    sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=10 >/dev/null 2>&1 || true
    sysctl -w net.netfilter.nf_conntrack_tcp_timeout_close_wait=10 >/dev/null 2>&1 || true

    # IPv6
    sysctl -w \
        net.ipv6.conf.all.accept_redirects=0 \
        net.ipv6.conf.all.accept_source_route=0 \
        >/dev/null 2>&1 || true

    # BBR congestion control
    modprobe tcp_bbr 2>/dev/null || true

    log OK "Kernel hardening tamamlandı (BBR + conntrack optimize)"
}

kernel_reset() {
    sysctl -w \
        net.ipv4.tcp_syncookies=1 \
        net.ipv4.conf.all.rp_filter=1 \
        net.ipv4.conf.all.log_martians=0 \
        net.netfilter.nf_conntrack_tcp_loose=1 \
        >/dev/null 2>&1 || true
}

# ════════════════════════════════════════════════════════════════════
# KATMAN 2: MANGLE/PREROUTING — EN ERKEN FİLTRELEME
# Paketler INPUT/FORWARD'a gelmeden DROP edilir
# Filter table'dan çok daha performanslı
# ════════════════════════════════════════════════════════════════════
mangle_apply() {
    [[ "$MANGLE_ENABLED" != "yes" ]] && { log INFO "Mangle devre dışı"; return; }
    log INFO "Mangle/PREROUTING kuralları uygulanıyor..."

    # Temizle
    iptables -t mangle -D PREROUTING -j EG_MANGLE 2>/dev/null
    iptables -t mangle -F EG_MANGLE 2>/dev/null
    iptables -t mangle -X EG_MANGLE 2>/dev/null
    iptables -t mangle -N EG_MANGLE
    iptables -t mangle -I PREROUTING 1 -j EG_MANGLE

    # Whitelist
    while IFS= read -r ip; do
        [[ -z "$ip" || "$ip" == \#* ]] && continue
        [[ ! "$ip" =~ : ]] && \
            iptables -t mangle -A EG_MANGLE -s "$ip" -j RETURN 2>/dev/null
    done < "$WL"

    # 1. Invalid paketler — en başta drop
    iptables -t mangle -A EG_MANGLE \
        -m conntrack --ctstate INVALID -j DROP

    # 2. Yeni bağlantı ama SYN değil (saldırı paketi)
    # NOT: SYNPROXY UNTRACKED gönderdiği için bu kural devre dışı
    # iptables -t mangle -A EG_MANGLE -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

    # 3. Şüpheli MSS değeri (saldırı araçları genelde yanlış MSS)
    if [[ "$L4_MSS_CHECK" == "yes" ]]; then
        iptables -t mangle -A EG_MANGLE \
            -p tcp -m conntrack --ctstate NEW \
            -m tcpmss ! --mss 536:65535 \
            -j LOG --log-prefix "[EG-MNG-MSS] " --log-level 4 2>/dev/null
        iptables -t mangle -A EG_MANGLE \
            -p tcp -m conntrack --ctstate NEW \
            -m tcpmss ! --mss 536:65535 -j DROP 2>/dev/null
    fi

    # 4. TCP Flag kombinasyonu saldırıları — TÜM kombinasyonlar
    # XMAS
    iptables -t mangle -A EG_MANGLE \
        -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,PSH,ACK,URG \
        -j LOG --log-prefix "[EG-MNG-XMAS] " --log-level 4
    iptables -t mangle -A EG_MANGLE \
        -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG FIN,SYN,RST,PSH,ACK,URG -j DROP
    # NULL
    iptables -t mangle -A EG_MANGLE \
        -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE \
        -j LOG --log-prefix "[EG-MNG-NULL] " --log-level 4
    iptables -t mangle -A EG_MANGLE \
        -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
    # Geçersiz flag kombinasyonları
    for flags in "FIN,SYN FIN,SYN" "SYN,RST SYN,RST" "FIN,RST FIN,RST" \
                  "FIN,ACK FIN" "ACK,URG URG" "ACK,FIN FIN" \
                  "ACK,PSH PSH" "FIN,PSH,URG FIN,PSH,URG" \
                  "SYN,FIN,PSH,URG SYN,FIN,PSH,URG" \
                  "FIN,SYN,RST,ACK,URG FIN,SYN,RST,ACK,URG"; do
        iptables -t mangle -A EG_MANGLE \
            -p tcp --tcp-flags $flags -j DROP 2>/dev/null
    done

    # 5. Bogon IP'ler — sahte/geçersiz kaynak IP (mangle'da çok hızlı)
    # Bogon IP'ler — Private IP aralıkları HARİÇ (LAN/VMware için gerekli)
    for bogon in \
        "0.0.0.0/8" "100.64.0.0/10" \
        "192.0.2.0/24" "198.18.0.0/15" "198.51.100.0/24" \
        "203.0.113.0/24" "224.0.0.0/3" "240.0.0.0/5"; do
        iptables -t mangle -A EG_MANGLE -s "$bogon" -j DROP 2>/dev/null
    done
    # NOT: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 LAN/VMware için açık bırakıldı

    # 6. TTL anomali tespiti (saldırı araçları düşük TTL kullanır)
    iptables -t mangle -A EG_MANGLE \
        -m ttl --ttl-lt "$L4_TTL_MIN" \
        -j LOG --log-prefix "[EG-MNG-TTL] " --log-level 4 2>/dev/null
    iptables -t mangle -A EG_MANGLE \
        -m ttl --ttl-lt "$L4_TTL_MIN" -j DROP 2>/dev/null

    # 7. Amplification port'larını PREROUTING'da engelle (en verimli)
    for port in 1900 11211 19 17 123 161 389 3389; do
        iptables -t mangle -A EG_MANGLE -p udp --dport $port -j DROP 2>/dev/null
    done

    # 8. Fragmented UDP paketler (çoğu saldırı)
    iptables -t mangle -A EG_MANGLE -p udp -f -j DROP 2>/dev/null

    local cnt; cnt=$(iptables -t mangle -L EG_MANGLE --line-numbers -n 2>/dev/null | grep -c "^[0-9]" || echo 0)
    log MANGLE "mangle/PREROUTING aktif ($cnt kural) — paketler INPUT'a gelmeden filtreleniyor"
}

# ════════════════════════════════════════════════════════════════════
# KATMAN 3: SYNPROXY — SYN FLOOD ULTRA KORUMA
# Kernel seviyesinde TCP proxy — 10x SYN handling kapasitesi
# ════════════════════════════════════════════════════════════════════
synproxy_apply() {
    [[ "$SYNPROXY_ENABLED" != "yes" ]] && { log INFO "SYNPROXY devre dışı"; return; }
    log INFO "SYNPROXY uygulanıyor..."

    # SYNPROXY için SYN paketleri conntrack'ten çıkar (raw table)
    iptables -t raw -D PREROUTING -j EG_SYNPROXY_RAW 2>/dev/null
    iptables -t raw -F EG_SYNPROXY_RAW 2>/dev/null
    iptables -t raw -X EG_SYNPROXY_RAW 2>/dev/null
    iptables -t raw -N EG_SYNPROXY_RAW
    iptables -t raw -I PREROUTING 1 -j EG_SYNPROXY_RAW

    # SYNPROXY INPUT zinciri
    iptables -D INPUT -j EG_SYNPROXY 2>/dev/null
    iptables -F EG_SYNPROXY 2>/dev/null
    iptables -X EG_SYNPROXY 2>/dev/null
    iptables -N EG_SYNPROXY

    # Belirtilen portlar için SYNPROXY uygula
    # Whitelist SYNPROXY'den muaf
    while IFS= read -r ip; do
        [[ -z "$ip" || "$ip" == \#* ]] && continue
        [[ ! "$ip" =~ : ]] && \
            iptables -A EG_SYNPROXY -s "$ip" -j RETURN 2>/dev/null
    done < "$WL"

    # SSH her zaman geçer — SYNPROXY'den muaf
    iptables -A EG_SYNPROXY -p tcp --dport 22 -j RETURN

    # ESTABLISHED/RELATED her zaman geçer
    iptables -A EG_SYNPROXY -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN

    IFS=',' read -ra SPORTS <<< "$SYNPROXY_PORTS"
    for port in "${SPORTS[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        [[ -z "$port" ]] && continue
        # SSH zaten muaf, atla
        [[ "$port" == "22" ]] && continue

        # raw: SYN paketlerini conntrack dışında tut (sadece bu port)
        iptables -t raw -A EG_SYNPROXY_RAW \
            -p tcp --dport "$port" --syn -j CT --notrack 2>/dev/null

        # SYNPROXY: sadece UNTRACKED SYN paketleri
        iptables -A EG_SYNPROXY \
            -p tcp --dport "$port" \
            -m conntrack --ctstate UNTRACKED \
            -j SYNPROXY \
            --sack-perm --timestamp \
            --wscale "$SYNPROXY_WSCALE" \
            --mss "$SYNPROXY_MSS" \
            2>/dev/null
    done

    # UNTRACKED kalan paketler drop (SYNPROXY başarısız)
    iptables -A EG_SYNPROXY -m conntrack --ctstate UNTRACKED -j DROP

    # EG_ACCEPT(1)'den hemen sonra INPUT 2'ye ekle
    # Sonuç: ACCEPT(1) -> SYNPROXY(2) -> GEOIP(3) -> L4(4) -> L7(5) -> GAME(6)
    # EG_SYNPROXY synproxy_apply() tarafından eklenir (apply_rules sonrası)

    log PROXY "SYNPROXY aktif — portlar: $SYNPROXY_PORTS (MSS:$SYNPROXY_MSS WSCALE:$SYNPROXY_WSCALE)"
    log PROXY "SYN flood kapasitesi ~10x artırıldı"
}

# ════════════════════════════════════════════════════════════════════
# KATMAN 4-6: IPTABLES — EG_ACCEPT / EG_L4 / EG_L7 / EG_GAME
# Her katman ayrı zincir → collect() sayaçları doğru çalışır
# ════════════════════════════════════════════════════════════════════
apply_rules() {
    log INFO "Firewall kuralları uygulanıyor..."

    # Önce mangle katmanını uygula (kapsamlı versiyon)
    mangle_apply

    # ── Tüm zincirleri temizle ve yeniden oluştur ──────────────────────
    for chain in EG_GUARD EG_ACCEPT EG_L4 EG_L7 EG_GAME; do
        iptables -D INPUT -j "$chain" 2>/dev/null
        iptables -F "$chain" 2>/dev/null
        iptables -X "$chain" 2>/dev/null
        iptables -N "$chain"
    done
    # EG_GUARD INPUT'un EN BAŞINA
    iptables -I INPUT 1 -j EG_GUARD

    # IPv6
    ip6tables -D INPUT -j EG_GUARD6 2>/dev/null
    ip6tables -F EG_GUARD6 2>/dev/null
    ip6tables -X EG_GUARD6 2>/dev/null
    ip6tables -N EG_GUARD6 2>/dev/null
    ip6tables -I INPUT 1 -j EG_GUARD6 2>/dev/null

    # ════════════════════════════════════════════════════════════
    # EG_GUARD — Ana dağıtıcı zincir
    # Paketler sırasıyla EG_ACCEPT → EG_L4 → EG_L7 → EG_GAME'den geçer
    # Her alt zincir: DROP = paket bitti, RETURN/fallthrough = sonraki zincir
    # ════════════════════════════════════════════════════════════
    iptables -A EG_GUARD -j EG_ACCEPT   # hızlı yol: whitelist/established/loopback
    iptables -A EG_GUARD -m conntrack --ctstate INVALID -j DROP
    iptables -A EG_GUARD -j EG_L4       # L4 saldırı filtresi
    iptables -A EG_GUARD -j EG_L7       # L7 uygulama filtresi
    iptables -A EG_GUARD -j EG_GAME     # Oyun sunucusu koruma

    # ════════════════════════════════════════════════════════════
    # EG_ACCEPT — Hızlı kabul zinciri
    # Loopback, ESTABLISHED ve whitelist → ACCEPT (terminal karar)
    # Eşleşmeyenler zincir sonuna düşer → EG_GUARD'a RETURN
    # ════════════════════════════════════════════════════════════
    iptables -A EG_ACCEPT -i lo -j ACCEPT
    iptables -A EG_ACCEPT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Whitelist IPs → doğrudan ACCEPT (tüm filtreleri atlar)
    while IFS= read -r ip; do
        [[ -z "$ip" || "$ip" == \#* ]] && continue
        if [[ "$ip" =~ : ]]; then
            ip6tables -A EG_GUARD6 -s "$ip" -j ACCEPT 2>/dev/null
        else
            iptables -A EG_ACCEPT -s "$ip" -j ACCEPT
        fi
    done < "$WL"

    # ════════════════════════════════════════════════════════════
    # EG_L4 — Katman 4 Saldırı Filtresi
    # SYN flood / ICMP flood / UDP flood / Port scan / Fragment / Bogon
    # ════════════════════════════════════════════════════════════

    # SYN Flood — global hız limiti
    iptables -A EG_L4 -p tcp --syn \
        -m limit --limit "${L4_SYN_RATE}/s" --limit-burst "$L4_SYN_BURST" -j RETURN
    iptables -A EG_L4 -p tcp --syn \
        -j LOG --log-prefix "[EG-L4-SYN] " --log-level 4
    iptables -A EG_L4 -p tcp --syn -j DROP

    # SYN Flood — IP başına hız limiti
    iptables -A EG_L4 -p tcp --syn \
        -m hashlimit --hashlimit-name eg_syn_ip \
        --hashlimit-above "${L4_SYN_PER_IP}/sec" \
        --hashlimit-mode srcip \
        --hashlimit-burst $((L4_SYN_PER_IP * 3)) \
        -j LOG --log-prefix "[EG-L4-SYN] " --log-level 4 2>/dev/null
    iptables -A EG_L4 -p tcp --syn \
        -m hashlimit --hashlimit-name eg_syn_ip \
        --hashlimit-above "${L4_SYN_PER_IP}/sec" \
        --hashlimit-mode srcip \
        --hashlimit-burst $((L4_SYN_PER_IP * 3)) -j DROP 2>/dev/null

    # IP başına eş zamanlı TCP bağlantı limiti
    iptables -A EG_L4 -p tcp \
        -m connlimit --connlimit-above "$L4_CONN_PER_IP" --connlimit-mask 32 \
        -j LOG --log-prefix "[EG-L4-CLIM] " --log-level 4
    iptables -A EG_L4 -p tcp \
        -m connlimit --connlimit-above "$L4_CONN_PER_IP" --connlimit-mask 32 -j DROP

    # ICMP Flood
    iptables -A EG_L4 -p icmp --icmp-type echo-request \
        -m limit --limit "${L4_ICMP_RATE}/s" --limit-burst $((L4_ICMP_RATE * 2)) -j RETURN
    iptables -A EG_L4 -p icmp --icmp-type echo-request \
        -j LOG --log-prefix "[EG-L4-ICMP] " --log-level 4
    iptables -A EG_L4 -p icmp --icmp-type echo-request -j DROP
    iptables -A EG_L4 -p icmp -j RETURN  # diğer ICMP türleri geçer

    # UDP Flood — IP başına hız limiti (genel; oyun portları EG_GAME'de ayrıca ele alınır)
    iptables -A EG_L4 -p udp \
        -m hashlimit --hashlimit-name eg_udp_ip \
        --hashlimit-above "${L4_UDP_PPS}/sec" \
        --hashlimit-mode srcip \
        --hashlimit-burst $((L4_UDP_PPS * 3)) \
        -j LOG --log-prefix "[EG-L4-UDP] " --log-level 4 2>/dev/null
    iptables -A EG_L4 -p udp \
        -m hashlimit --hashlimit-name eg_udp_ip \
        --hashlimit-above "${L4_UDP_PPS}/sec" \
        --hashlimit-mode srcip \
        --hashlimit-burst $((L4_UDP_PPS * 3)) -j DROP 2>/dev/null

    # RST Flood koruması
    iptables -A EG_L4 -p tcp --tcp-flags RST RST \
        -m limit --limit 10/s --limit-burst 20 -j RETURN
    iptables -A EG_L4 -p tcp --tcp-flags RST RST \
        -j LOG --log-prefix "[EG-L4-RST] " --log-level 4 2>/dev/null
    iptables -A EG_L4 -p tcp --tcp-flags RST RST -j DROP 2>/dev/null

    # Parçalanmış paketler
    iptables -A EG_L4 -f \
        -j LOG --log-prefix "[EG-L4-FRAG] " --log-level 4
    iptables -A EG_L4 -f -j DROP

    # Bogon IP'ler (Private aralıklar hariç — LAN/VMware için gerekli)
    for bogon in "0.0.0.0/8" "100.64.0.0/10" \
                  "192.0.2.0/24" "198.51.100.0/24" "203.0.113.0/24" \
                  "224.0.0.0/4" "240.0.0.0/4"; do
        iptables -A EG_L4 -s "$bogon" -j DROP 2>/dev/null
    done

    # DNS amplifikasyon koruması
    iptables -A EG_L4 -p udp --dport 53 \
        -m hashlimit --hashlimit-name eg_dns \
        --hashlimit-above "60/sec" --hashlimit-mode srcip \
        --hashlimit-burst 120 -j DROP 2>/dev/null

    # Port tarama tespiti
    iptables -A EG_L4 -m recent --name EG_SCAN \
        --rcheck --seconds 60 --hitcount 30 \
        -j LOG --log-prefix "[EG-L4-SCAN] " --log-level 4
    iptables -A EG_L4 -m recent --name EG_SCAN \
        --rcheck --seconds 60 --hitcount 30 -j DROP
    iptables -A EG_L4 -m recent --name EG_SCAN --set -j RETURN

    local l4_cnt; l4_cnt=$(iptables -L EG_L4 -n 2>/dev/null | grep -c "^DROP\|^LOG" || echo 0)
    log OK "EG_L4 aktif ($l4_cnt kural) — SYN/ICMP/UDP/RST/Scan/Frag/Bogon"

    # ════════════════════════════════════════════════════════════
    # EG_L7 — Katman 7 Uygulama Filtresi
    # HTTP/HTTPS flood, SSH brute force, FTP brute force
    # NOT: Portlar burada RATE LİMİT'e tabi tutulur, sonra geçer
    # ════════════════════════════════════════════════════════════

    # ── SSH Brute Force Koruması ──────────────────────────────────
    # Eşik aşılmadan önce RETURN, aşılınca LOG+DROP
    iptables -A EG_L7 -p tcp --dport 22 --syn \
        -m hashlimit --hashlimit-name eg_ssh \
        --hashlimit-upto "${L7_SSH_RATE}/min" \
        --hashlimit-mode srcip \
        --hashlimit-burst 10 -j RETURN 2>/dev/null
    iptables -A EG_L7 -p tcp --dport 22 --syn \
        -j LOG --log-prefix "[EG-SSH-BF] " --log-level 4 2>/dev/null
    iptables -A EG_L7 -p tcp --dport 22 --syn -j DROP 2>/dev/null

    # ── RapidReset (HTTP/2 SETTINGS flood) ──────────────────────
    # Çok hızlı TCP reset paketleri IP başına limitle
    iptables -A EG_L7 -p tcp --dport 80 --tcp-flags RST RST \
        -m hashlimit --hashlimit-name eg_reset_80 \
        --hashlimit-above "50/sec" --hashlimit-mode srcip \
        --hashlimit-burst 100 -j DROP 2>/dev/null
    iptables -A EG_L7 -p tcp --dport 443 --tcp-flags RST RST \
        -m hashlimit --hashlimit-name eg_reset_443 \
        --hashlimit-above "50/sec" --hashlimit-mode srcip \
        --hashlimit-burst 100 -j DROP 2>/dev/null

    # ── HTTP Flood Koruması (Port 80) ─────────────────────────────
    iptables -A EG_L7 -p tcp --dport 80 \
        -m connlimit --connlimit-above "$L7_HTTP_CONN" --connlimit-mask 32 \
        -j LOG --log-prefix "[EG-L7-HTTP-GET] " --log-level 4
    iptables -A EG_L7 -p tcp --dport 80 \
        -m connlimit --connlimit-above "$L7_HTTP_CONN" --connlimit-mask 32 -j DROP
    iptables -A EG_L7 -p tcp --dport 80 --syn \
        -m hashlimit --hashlimit-name eg_http_new \
        --hashlimit-upto "${L7_HTTP_RATE}/sec" \
        --hashlimit-mode srcip --hashlimit-burst 200 -j RETURN 2>/dev/null
    iptables -A EG_L7 -p tcp --dport 80 --syn \
        -j LOG --log-prefix "[EG-L7-HTTP-SYN] " --log-level 4 2>/dev/null
    iptables -A EG_L7 -p tcp --dport 80 --syn -j DROP 2>/dev/null

    # ── HTTPS Flood Koruması (Port 443) ──────────────────────────
    iptables -A EG_L7 -p tcp --dport 443 \
        -m connlimit --connlimit-above "$L7_HTTP_CONN" --connlimit-mask 32 \
        -j LOG --log-prefix "[EG-L7-HTTPS-GET] " --log-level 4
    iptables -A EG_L7 -p tcp --dport 443 \
        -m connlimit --connlimit-above "$L7_HTTP_CONN" --connlimit-mask 32 -j DROP
    iptables -A EG_L7 -p tcp --dport 443 --syn \
        -m hashlimit --hashlimit-name eg_https_new \
        --hashlimit-upto "${L7_HTTP_RATE}/sec" \
        --hashlimit-mode srcip --hashlimit-burst 200 -j RETURN 2>/dev/null
    iptables -A EG_L7 -p tcp --dport 443 --syn \
        -j LOG --log-prefix "[EG-L7-HTTPS-SYN] " --log-level 4 2>/dev/null
    iptables -A EG_L7 -p tcp --dport 443 --syn -j DROP 2>/dev/null

    # ── Slowloris / Partial-Request Koruması ──────────────────────
    # Incomplete bağlantı sayısını sınırla (connlimit saddr bazında)
    iptables -A EG_L7 -p tcp --dport 80 \
        -m connlimit --connlimit-above $((L7_HTTP_CONN / 2)) \
        --connlimit-mask 32 --connlimit-saddr -j DROP 2>/dev/null
    iptables -A EG_L7 -p tcp --dport 443 \
        -m connlimit --connlimit-above $((L7_HTTP_CONN / 2)) \
        --connlimit-mask 32 --connlimit-saddr -j DROP 2>/dev/null

    # ── FTP Brute Force Koruması ──────────────────────────────────
    iptables -A EG_L7 -p tcp --dport 21 \
        -m hashlimit --hashlimit-name eg_ftp \
        --hashlimit-above "10/min" --hashlimit-mode srcip \
        --hashlimit-burst 15 -j DROP 2>/dev/null

    # ── SMTP Brute Force Koruması ─────────────────────────────────
    iptables -A EG_L7 -p tcp -m multiport --dports 25,465,587 \
        -m hashlimit --hashlimit-name eg_smtp \
        --hashlimit-above "20/min" --hashlimit-mode srcip \
        --hashlimit-burst 30 -j DROP 2>/dev/null

    local l7_cnt; l7_cnt=$(iptables -L EG_L7 -n 2>/dev/null | grep -c "^DROP\|^LOG" || echo 0)
    log OK "EG_L7 aktif ($l7_cnt kural) — HTTP/HTTPS/SSH/FTP flood koruması"

    # ════════════════════════════════════════════════════════════
    # EG_GAME — Oyun Sunucusu Koruma Katmanı
    # UDP/TCP flood + RCON brute force
    # ════════════════════════════════════════════════════════════
    if [[ "$GAME_ENABLED" == "yes" ]]; then
        IFS=',' read -ra UPORTS <<< "$GAME_PORTS_UDP"
        for port in "${UPORTS[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            [[ -z "$port" ]] && continue
            iptables -A EG_GAME -p udp --dport "$port" \
                -m hashlimit --hashlimit-name "eg_gu${port}" \
                --hashlimit-above "${GAME_UDP_PPS}/sec" \
                --hashlimit-mode srcip \
                --hashlimit-burst "$GAME_UDP_BURST" \
                -j LOG --log-prefix "[EG-GAME-UDP] " --log-level 4 2>/dev/null
            iptables -A EG_GAME -p udp --dport "$port" \
                -m hashlimit --hashlimit-name "eg_gu${port}" \
                --hashlimit-above "${GAME_UDP_PPS}/sec" \
                --hashlimit-mode srcip \
                --hashlimit-burst "$GAME_UDP_BURST" -j DROP 2>/dev/null
            # Sıfır/mini UDP paketleri — sahte trafik
            iptables -A EG_GAME -p udp --dport "$port" \
                -m length --length 0:15 -j DROP 2>/dev/null
        done
        IFS=',' read -ra TPORTS <<< "$GAME_PORTS_TCP"
        for port in "${TPORTS[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            [[ -z "$port" ]] && continue
            iptables -A EG_GAME -p tcp --dport "$port" \
                -m connlimit --connlimit-above "$GAME_TCP_CONN" --connlimit-mask 32 \
                -j LOG --log-prefix "[EG-GAME-TCP] " --log-level 4
            iptables -A EG_GAME -p tcp --dport "$port" \
                -m connlimit --connlimit-above "$GAME_TCP_CONN" --connlimit-mask 32 -j DROP
            iptables -A EG_GAME -p tcp --dport "$port" --syn \
                -m hashlimit --hashlimit-name "eg_gn${port}" \
                --hashlimit-above "8/sec" --hashlimit-mode srcip \
                --hashlimit-burst 20 -j DROP 2>/dev/null
        done
        # RCON brute force (27015, 25575)
        for rp in 27015 25575; do
            iptables -A EG_GAME -p tcp --dport "$rp" \
                -m hashlimit --hashlimit-name "eg_rc${rp}" \
                --hashlimit-above "5/min" --hashlimit-mode srcip \
                --hashlimit-burst 10 \
                -j LOG --log-prefix "[EG-GAME-RCON] " --log-level 4 2>/dev/null
            iptables -A EG_GAME -p tcp --dport "$rp" \
                -m hashlimit --hashlimit-name "eg_rc${rp}" \
                --hashlimit-above "5/min" --hashlimit-mode srcip \
                --hashlimit-burst 10 -j DROP 2>/dev/null
        done
        log GAME "EG_GAME aktif — UDP/TCP flood + RCON koruması"
    fi

    # ── IPv6 Temel Koruma ─────────────────────────────────────────
    ip6tables -A EG_GUARD6 -i lo -j ACCEPT 2>/dev/null
    ip6tables -A EG_GUARD6 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null
    ip6tables -A EG_GUARD6 -m conntrack --ctstate INVALID -j DROP 2>/dev/null
    ip6tables -A EG_GUARD6 -p tcp --syn \
        -m limit --limit "${L4_SYN_RATE}/s" --limit-burst "$L4_SYN_BURST" -j RETURN 2>/dev/null
    ip6tables -A EG_GUARD6 -p tcp --syn -j DROP 2>/dev/null
    # HTTP/HTTPS IPv6 flood
    ip6tables -A EG_GUARD6 -p tcp --dport 80 \
        -m connlimit --connlimit-above "$L7_HTTP_CONN" --connlimit-mask 128 -j DROP 2>/dev/null
    ip6tables -A EG_GUARD6 -p tcp --dport 443 \
        -m connlimit --connlimit-above "$L7_HTTP_CONN" --connlimit-mask 128 -j DROP 2>/dev/null
    ip6tables -A EG_GUARD6 -p icmpv6 \
        -m limit --limit 50/s --limit-burst 100 -j RETURN 2>/dev/null
    ip6tables -A EG_GUARD6 -p icmpv6 -j DROP 2>/dev/null

    local cnt
    cnt=$(iptables -L EG_GUARD --line-numbers -n 2>/dev/null | grep -c "^[0-9]" || echo 0)
    log OK "Firewall aktif — EG_ACCEPT+EG_L4+EG_L7+EG_GAME ($cnt GUARD kural) — SSH+Web korumalı"
}

rules_remove() {
    log INFO "Kurallar kaldırılıyor..."
    # Tüm zincirler temizle (EG_GUARD önce — alt zincirler bağımlı)
    for chain in EG_GUARD EG_ACCEPT EG_L4 EG_L7 EG_GAME; do
        iptables -D INPUT -j "$chain" 2>/dev/null
        iptables -F "$chain" 2>/dev/null
        iptables -X "$chain" 2>/dev/null
    done
    # Mangle temizle
    iptables -t mangle -D PREROUTING -j EG_MANGLE 2>/dev/null
    iptables -t mangle -F EG_MANGLE 2>/dev/null
    iptables -t mangle -X EG_MANGLE 2>/dev/null
    # SYNPROXY raw temizle
    iptables -t raw -D PREROUTING -j EG_SYNPROXY_RAW 2>/dev/null
    iptables -t raw -F EG_SYNPROXY_RAW 2>/dev/null
    iptables -t raw -X EG_SYNPROXY_RAW 2>/dev/null
    iptables -D INPUT -j EG_SYNPROXY 2>/dev/null
    iptables -F EG_SYNPROXY 2>/dev/null
    iptables -X EG_SYNPROXY 2>/dev/null
    # IPv6
    ip6tables -D INPUT -j EG_GUARD6 2>/dev/null
    ip6tables -F EG_GUARD6 2>/dev/null
    ip6tables -X EG_GUARD6 2>/dev/null
    log OK "Tüm kurallar kaldırıldı (EG_GUARD + EG_L4 + EG_L7 + EG_GAME + mangle)"
}

ip_unblock() {
    local ip=$1 reason=${2:-manual}
    # Tüm zincirlerde engeli kaldır
    iptables -D EG_GUARD  -s "$ip" -j DROP 2>/dev/null
    iptables -D EG_L4     -s "$ip" -j DROP 2>/dev/null
    iptables -t mangle -D EG_MANGLE -s "$ip" -j DROP 2>/dev/null
    command -v fail2ban-client >/dev/null 2>&1 && \
        fail2ban-client set eagle-guard-scan unbanip "$ip" 2>/dev/null || true
    command -v ipset >/dev/null 2>&1 && \
        ipset del eagle_blocked "$ip" 2>/dev/null || true
    log INFO "Engel kaldırıldı: $ip ($reason)"
    _jblock "$ip" "$reason" "" remove
}


ip_block() {
    local ip=$1 reason=${2:-manual} layer=${3:-L4} method=${4:-GET}
    [[ -z "$ip" ]] && return 1
    grep -qF "$ip" "$WL" 2>/dev/null && { log WARN "Whitelist: $ip"; return 1; }
    iptables -C EG_GUARD -s "$ip" -j DROP 2>/dev/null && return 0
    iptables -I EG_GUARD 1 -s "$ip" -j DROP
    iptables -t mangle -I EG_MANGLE 1 -s "$ip" -j DROP 2>/dev/null
    command -v fail2ban-client >/dev/null 2>&1 && \
        fail2ban-client set eagle-guard-scan banip "$ip" 2>/dev/null || true
    log ALERT "[$layer] ENGELLENDİ: $ip — $reason [$method]"
    log_attack "BLOCKED ip=$ip reason=$reason layer=$layer method=$method"
    _jblock "$ip" "$reason" "$layer" add
    notify "block" "🚫 IP Engellendi [$layer]" "IP: $ip | Sebep: $reason | Method: $method" "high"
    [[ "$BAN_TIME" -gt 0 ]] && (sleep "$BAN_TIME"; ip_unblock "$ip" ban_expired) &
}


_jblock() {
    python3 - <<PY 2>/dev/null
import json
f="$BLOCKED"
try: d=json.load(open(f))
except: d={"blocked":[]}
ts=__import__('datetime').datetime.utcnow().isoformat()+'Z'
if "$4"=="add":
    x=next((i for i in d["blocked"] if i["ip"]=="$1"),None)
    if x: x["hits"]=x.get("hits",1)+1; x["last"]="$ts"
    else: d["blocked"].insert(0,{"ip":"$1","reason":"$2","layer":"$3","time":ts,"hits":1})
    d["blocked"]=d["blocked"][:500]
else: d["blocked"]=[i for i in d["blocked"] if i["ip"]!="$1"]
json.dump(d,open(f,"w"))
PY
}


# ── Bildirim backend'leri (v7.2) ──────────────────────────────────
send_discord() {
    local title="$1" detail="$2" color="${3:-3447003}"
    [[ -z "${DISCORD_WEBHOOK:-}" ]] && return 0
    [[ "$DISCORD_WEBHOOK" != http*://* ]] && { log WARN "DISCORD_WEBHOOK geçersiz URL"; return 1; }
    command -v curl >/dev/null 2>&1 || { log WARN "curl yok — Discord atlandı"; return 1; }

    local host; host=$(hostname 2>/dev/null || echo "unknown")
    local ts;   ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local payload
    payload=$(python3 -c '
import json,sys
print(json.dumps({
  "username":"Eagle Guard",
  "avatar_url":"https://cdn-icons-png.flaticon.com/512/2826/2826131.png",
  "embeds":[{
    "title":sys.argv[1][:256],
    "description":sys.argv[2][:4000],
    "color":int(sys.argv[3]),
    "timestamp":sys.argv[4],
    "footer":{"text":"Eagle Guard @ "+sys.argv[5]}
  }]
}))' "$title" "$detail" "$color" "$ts" "$host" 2>/dev/null) || \
    payload=$(printf '{"username":"Eagle Guard","content":"**%s**\\n%s\\n_host: %s_"}' \
              "${title//\"/\\\"}" "${detail//\"/\\\"}" "$host")

    # Çoklu strateji: TLS handshake hatalarını (curl rc=35, Connection reset) aşmak için
    local http_code curl_err=0
    local ca_bundle=""
    for c in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem; do
        [[ -r "$c" ]] && { ca_bundle="$c"; break; }
    done

    _try_curl() {
        local label="$1"; shift
        http_code=$(curl -sS -4 -L -o /tmp/eg-discord.out -w '%{http_code}' \
             --connect-timeout 8 --max-time 15 \
             -A 'Mozilla/5.0 (EagleGuard/7.2)' \
             -H 'Content-Type: application/json' \
             -X POST --data-binary "$payload" \
             "$@" \
             "$DISCORD_WEBHOOK" 2>>/tmp/eg-discord.err)
        curl_err=$?
        if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
            log OK "Discord [$label] → $title (HTTP $http_code)"
            return 0
        fi
        return 1
    }

    : > /tmp/eg-discord.err
    # 1) Standart (HTTP/2 + modern TLS)
    _try_curl "std" && return 0
    # 2) HTTP/1.1 + TLS 1.2 (HTTP/2 ALPN veya TLS 1.3 sorunları için)
    _try_curl "h1-tls12" --http1.1 --tlsv1.2 --tls-max 1.2 && return 0
    # 3) Açık CA bundle + HTTP/1.1
    if [[ -n "$ca_bundle" ]]; then
        _try_curl "cacert" --http1.1 --cacert "$ca_bundle" && return 0
    fi
    # 4) Cloudflare DNS (resolv.conf bozuksa)
    _try_curl "cf-dns" --http1.1 --dns-servers 1.1.1.1,8.8.8.8 && return 0
    # 5) TLS doğrulama kapalı — SON ÇARE (MITM/eski CA senaryosu)
    _try_curl "insecure" --http1.1 -k && {
        log WARN "Discord insecure modda gönderildi — 'sudo apt install --reinstall ca-certificates' önerilir"
        return 0
    }

    # 6) wget fallback (farklı TLS stack)
    if command -v wget >/dev/null 2>&1; then
        if wget -q -4 --tries=1 --timeout=10 --no-check-certificate \
               --header='Content-Type: application/json' \
               --post-data="$payload" \
               -O /tmp/eg-discord.wget "$DISCORD_WEBHOOK" 2>>/tmp/eg-discord.err; then
            log OK "Discord (wget fallback) → $title"
            return 0
        fi
    fi
    # 7) python fallback (son çare)
    if command -v python3 >/dev/null 2>&1; then
        if python3 - "$DISCORD_WEBHOOK" "$payload" <<'PY' 2>>/tmp/eg-discord.err; then
import sys, json, ssl, urllib.request
url, body = sys.argv[1], sys.argv[2]
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
req = urllib.request.Request(url, data=body.encode(), headers={
    'Content-Type':'application/json','User-Agent':'EagleGuard-py'
}, method='POST')
try:
    r = urllib.request.urlopen(req, timeout=12, context=ctx)
    print("HTTP", r.status); sys.exit(0 if 200<=r.status<300 else 2)
except Exception as e:
    print("ERR", e); sys.exit(3)
PY
            log OK "Discord (python fallback) → $title"
            return 0
        fi
    fi

    local errmsg="HTTP=$http_code curl_rc=$curl_err"
    [[ -s /tmp/eg-discord.err ]] && errmsg="$errmsg | $(tail -c 300 /tmp/eg-discord.err | tr '\n' ' ')"
    log WARN "Discord başarısız ($errmsg)"
    case "$curl_err" in
      6)  log WARN "Tanı: DNS çözülemedi — /etc/resolv.conf kontrol, 'dig discord.com' ile test" ;;
      7)  log WARN "Tanı: Bağlantı kurulamıyor — firewall/NAT/OUTPUT 443 engelli olabilir" ;;
      28) log WARN "Tanı: Zaman aşımı — sunucu HTTPS çıkışı yavaş/kapalı" ;;
      35|60) log WARN "Tanı: TLS/SSL hatası — 'sudo apt install --reinstall ca-certificates openssl' deneyin; veya middlebox SNI filtresi (Cloudflare/Discord'a TCP 443 izin verilmeli)" ;;
      *)  log WARN "Tanı: 'curl -v --tlsv1.2 https://discord.com/api/v10/gateway' ile elle test edin" ;;
    esac
    return 2
}

send_telegram() {
    local title="$1" detail="$2" emoji="${3:-🔵}"
    [[ -z "${TELEGRAM_BOT:-}" || -z "${TELEGRAM_CHAT:-}" ]] && return 0
    command -v curl >/dev/null 2>&1 || return 1
    local host; host=$(hostname 2>/dev/null || echo "?")
    local text="${emoji} *${title}*
${detail}
_host:_ ${host}"
    curl -s --connect-timeout 5 --max-time 10 \
        -d "chat_id=${TELEGRAM_CHAT}" --data-urlencode "text=${text}" \
        -d "parse_mode=Markdown" \
        "https://api.telegram.org/bot${TELEGRAM_BOT}/sendMessage" >/dev/null 2>&1 \
        && log OK "Telegram → $title" \
        || log WARN "Telegram başarısız"
}

send_email() {
    local subject="$1" body="$2"
    [[ -z "${EMAIL_TO:-}" ]] && return 0
    command -v mail >/dev/null 2>&1 || return 1
    local host; host=$(hostname 2>/dev/null || echo "?")
    printf "%s\n\n%s" \
        "Content-Type: text/html; charset=utf-8" \
        "$body<br><br><small>Eagle Guard @ $host</small>" \
        | mail -a "Content-Type: text/html" -s "[Eagle Guard] $subject" "$EMAIL_TO" 2>/dev/null \
        && log OK "Email → $subject" \
        || log WARN "Email başarısız"
}

notify() {
    local type="$1" title="$2" detail="$3" sev="${4:-medium}"
    python3 - <<PY 2>/dev/null
import json
f="$ALERTS"
try: d=json.load(open(f))
except: d={"alerts":[]}
import datetime
d["alerts"].insert(0,{"type":"$type","title":"$title","detail":"$detail",
  "severity":"$sev","time":datetime.datetime.utcnow().isoformat()+"Z","read":False})
d["alerts"]=d["alerts"][:200]
json.dump(d,open(f,"w"))
PY
    local color emoji
    case "$sev" in
        high)   color=15158332; emoji="🔴" ;;
        medium) color=16776960; emoji="🟡" ;;
        low)    color=65280;    emoji="🟢" ;;
        *)      color=3447003;  emoji="🔵" ;;
    esac
    send_discord "$title" "$detail" "$color"
    send_telegram "$title" "$detail" "$emoji"
    send_email "$title" "<b>$title</b><br>$detail"
}


report_loop() {
    [[ "$REPORT_ENABLED" != "yes" ]] && return
    while true; do
        sleep "$REPORT_INTERVAL"
        load_conf
        generate_report
    done
}


generate_report() {
    log RPT "Detaylı saldırı raporu oluşturuluyor..."

    python3 - <<'PY' 2>/dev/null
import json, datetime, os, re, subprocess

# Stats oku
try: st = json.load(open("/opt/eagle-guard/data/stats.json"))
except: st = {}

# Engellenen IP'ler
try:
    blk = json.load(open("/opt/eagle-guard/data/blocked.json"))
    blocked_list = blk.get("blocked", [])
    today = datetime.date.today().isoformat()
    blocked_today = [b for b in blocked_list if b.get("time","")[:10] == today]
except: blocked_today = []

# Alertler
try:
    alts = json.load(open("/opt/eagle-guard/data/alerts.json"))
    alerts_today = [a for a in alts.get("alerts",[]) if a.get("time","")[:10] == datetime.date.today().isoformat()]
    high_alerts  = [a for a in alerts_today if a.get("severity") == "high"]
except: alerts_today = []; high_alerts = []

# Trafik analizi
try:
    trf = json.load(open("/opt/eagle-guard/data/traffic.json"))
    pts = trf.get("points", [])
    yesterday = (datetime.datetime.utcnow() - datetime.timedelta(hours=24)).isoformat()
    recent = [p for p in pts if p.get("t","") > yesterday]
    max_pps = max((p.get("pps_in",0) for p in recent), default=0)
    avg_pps = int(sum(p.get("pps_in",0) for p in recent) / max(len(recent),1))
    max_bps = max((p.get("bps_in",0) for p in recent), default=0)
except: max_pps = avg_pps = max_bps = 0

# Saldırı vektör analizi (kernel log'dan)
vectors = {}
for logf in ["/var/log/kern.log", "/var/log/syslog"]:
    if not os.path.exists(logf): continue
    try:
        with open(logf) as f:
            for line in f.readlines()[-5000:]:
                for pattern in ["EG-MNG-XMAS", "EG-MNG-NULL", "EG-MNG-NOSYN", "EG-MNG-MSS",
                                 "EG-L4-SYN", "EG-L4-ICMP", "EG-L4-FRAG", "EG-L4-SCAN",
                                 "EG-L4-CLIM", "EG-L4-UDP", "EG-L4-TTL",
                                 "EG-SSH-BF", "EG-GAME-UDP", "EG-GAME-TCP", "EG-GAME-RCON",
                                 "EG-GEO"]:
                    if pattern in line:
                        vectors[pattern] = vectors.get(pattern, 0) + 1
    except: pass

# En çok saldıran IP'ler
top_attackers = sorted(blocked_today, key=lambda x: x.get("hits",0), reverse=True)[:10]

# Rapor oluştur
l4  = st.get("l4", {})
l7  = st.get("l7", {})
gm  = st.get("game", {})
mng = st.get("mangle", {})
sp  = st.get("synproxy", {})

report = {
    "date":              datetime.date.today().isoformat(),
    "generated_at":      datetime.datetime.utcnow().isoformat() + "Z",
    "hostname":          os.uname().nodename,
    "uptime_hours":      round(st.get("sys",{}).get("uptime",0)/3600, 1),
    "summary": {
        "total_blocked":     len(blocked_today),
        "total_alerts":      len(alerts_today),
        "high_severity":     len(high_alerts),
        "unique_attackers":  len(set(b.get("ip") for b in blocked_today)),
        "max_pps":           max_pps,
        "avg_pps":           avg_pps,
        "max_mbps":          round(max_bps/1048576, 2),
    },
    "attack_vectors": {
        "mangle": {
            "xmas_null":     vectors.get("EG-MNG-XMAS",0) + vectors.get("EG-MNG-NULL",0),
            "bad_syn":       vectors.get("EG-MNG-NOSYN",0),
            "bad_mss":       vectors.get("EG-MNG-MSS",0),
            "total":         mng.get("total",0),
        },
        "synproxy": {
            "syn_received":  sp.get("syn_received",0),
            "established":   sp.get("established",0),
        },
        "l4": {
            "syn_flood":     l4.get("syn",0) + vectors.get("EG-L4-SYN",0),
            "icmp_flood":    l4.get("icmp",0),
            "frag_attack":   l4.get("frag",0),
            "port_scan":     l4.get("scan",0) + vectors.get("EG-L4-SCAN",0),
            "udp_flood":     vectors.get("EG-L4-UDP",0),
            "total":         l4.get("total",0),
        },
        "l7": {
            "ssh_brute":     l7.get("ssh",0) + vectors.get("EG-SSH-BF",0),
            "http_flood":    l7.get("http",0),
            "total":         l7.get("total",0),
        },
        "game": {
            "udp_flood":     gm.get("udp_flood",0) + vectors.get("EG-GAME-UDP",0),
            "tcp_flood":     gm.get("tcp_flood",0),
            "rcon_brute":    gm.get("rcon",0) + vectors.get("EG-GAME-RCON",0),
            "total":         gm.get("total",0),
        },
        "geoip": st.get("geoip", {}),
        "suricata": st.get("suricata", {}),
        "fail2ban": st.get("fail2ban", {}),
    },
    "top_attackers": top_attackers,
    "raw_vectors": vectors,
    "timeline": [{"time": p.get("t","")[:19], "pps": p.get("pps_in",0),
                  "mbps": round(p.get("bps_in",0)/1048576,2),
                  "conn": p.get("conn",0)} for p in recent[-48:]],
}

# Rapor DB'ye ekle
try:
    rdb = json.load(open("/opt/eagle-guard/data/report.json"))
except:
    rdb = {"reports": []}
rdb["reports"].insert(0, report)
rdb["reports"] = rdb["reports"][:90]
json.dump(rdb, open("/opt/eagle-guard/data/report.json","w"))

# Konsol özeti
total = report["summary"]["total_blocked"]
av = report["attack_vectors"]
print(f"""
╔══════════════════════════════════════════════════════════╗
║  Eagle Guard v7.2 — Detaylı Saldırı Raporu              ║
╠══════════════════════════════════════════════════════════╣
  📅 Tarih       : {report['date']}
  🖥  Sunucu      : {report['hostname']}
  ⏰ Uptime      : {report['uptime_hours']} saat
  ──────────────────────────────────────────────────────
  🚫 Engellenen  : {total} IP
  🔔 Alert       : {report['summary']['total_alerts']} ({report['summary']['high_severity']} yüksek)
  📦 Max PPS     : {report['summary']['max_pps']:,} pkt/s
  📡 Max Bant    : {report['summary']['max_mbps']} MB/s
  ──────────────────────────────────────────────────────
  SALDIRI VEKTÖRLERİ:
  ⚡ Mangle      : {av['mangle']['total']:,} paket (erken engelleme)
     XMAS/NULL  : {av['mangle']['xmas_null']:,}
     Bad SYN    : {av['mangle']['bad_syn']:,}
  🔒 SYNPROXY    : {av['synproxy']['syn_received']:,} SYN alındı
  🔵 L4 Toplam  : {av['l4']['total']:,}
     SYN Flood  : {av['l4']['syn_flood']:,}
     ICMP Flood : {av['l4']['icmp_flood']:,}
     Port Scan  : {av['l4']['port_scan']:,}
     UDP Flood  : {av['l4']['udp_flood']:,}
  🟡 L7 Toplam  : {av['l7']['total']:,}
     SSH Brute  : {av['l7']['ssh_brute']:,}
  🎮 Game Toplam: {av['game']['total']:,}
     UDP Flood  : {av['game']['udp_flood']:,}
     RCON Brute : {av['game']['rcon_brute']:,}
╚══════════════════════════════════════════════════════════╝
""")
PY
    log RPT "Rapor oluşturuldu → /opt/eagle-guard/data/report.json"
    notify "report" "📊 Güvenlik Raporu" "Günlük rapor hazır — $(hostname)" "low"
}


# ── Anomali tespiti (collect() tarafından çağrılır) ───────────────────
anomaly_detect() {
    local pps=$1 bps=$2 conn=$3
    [[ "$ANOMALY_ENABLED" != "yes" ]] && return

    local triggered=0 reason=""

    if [[ "$pps" -gt "$ANOMALY_PPS_THRESHOLD" ]] 2>/dev/null; then
        triggered=1; reason="PPS:${pps}>${ANOMALY_PPS_THRESHOLD}"
    fi
    if [[ "$bps" -gt "$ANOMALY_BPS_THRESHOLD" ]] 2>/dev/null; then
        triggered=1; reason="${reason:+$reason | }BPS:${bps}>${ANOMALY_BPS_THRESHOLD}"
    fi
    if [[ "$conn" -gt "$ANOMALY_CONN_THRESHOLD" ]] 2>/dev/null; then
        triggered=1; reason="${reason:+$reason | }CONN:${conn}>${ANOMALY_CONN_THRESHOLD}"
    fi

    if [[ "$triggered" -eq 1 ]]; then
        log ALERT "TRAFİK ANOMALİSİ: $reason"
        notify "anomaly" "⚡ Trafik Anomalisi Tespit Edildi" \
            "**Eşik aşıldı:** $reason
**PPS:** ${pps} | **BPS:** ${bps} | **CONN:** ${conn}" "high"
        # Oto-ban: en çok bağlantı yapan IP'yi tespit et
        if [[ "$ANOMALY_AUTOBLOCK" == "yes" ]]; then
            local top_ip
            top_ip=$(ss -tn 2>/dev/null | awk '/ESTABLISHED/{print $5}' | \
                cut -d: -f1 | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
            if [[ -n "$top_ip" && "$top_ip" != "127.0.0.1" ]]; then
                ip_block "$top_ip" "anomaly:${reason}" L4
            fi
        fi
    fi
}

# ── GeoIP veritabanı güncelleme ───────────────────────────────────────
geoip_update() {
    log INFO "GeoIP veritabanı güncelleniyor..."
    local db_dir="$EAGLE_DIR/data"
    mkdir -p "$db_dir"

    # Kamuya açık GeoLite2-Country.mmdb (MaxMind key gerektirmez)
    local url="https://raw.githubusercontent.com/P3TERX/GeoLite.mmdb/download/GeoLite2-Country.mmdb"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 60 -o "$db_dir/GeoLite2-Country.mmdb.new" "$url" \
            && mv "$db_dir/GeoLite2-Country.mmdb.new" "$db_dir/GeoLite2-Country.mmdb" \
            && log OK "GeoIP DB güncellendi ($(du -sh "$db_dir/GeoLite2-Country.mmdb" 2>/dev/null | cut -f1))" \
            || log WARN "GeoIP DB indirilemedi"
    else
        log WARN "curl yok — GeoIP güncellenemedi"
    fi

    # GeoIP iptables kural güncelle (ipset ile)
    if [[ "$GEOIP_ENABLED" == "yes" && -n "$GEOIP_BLOCK_COUNTRIES" ]]; then
        log INFO "GeoIP iptables kuralları güncelleniyor: $GEOIP_BLOCK_COUNTRIES"
        command -v geoiplookup >/dev/null 2>&1 || log WARN "geoiplookup yok — 'apt install geoip-bin' gerekli"
    fi
}

show_help() {
    echo -e "${C}╔══════════════════════════════════════════════════════════════╗${N}"
    echo -e "${W}║  🦅  Eagle Guard v7.2 — Enterprise DDoS Koruma Sistemi       ║${N}"
    echo -e "${Y}║  Powered By Creart Cloud                                     ║${N}"
    echo -e "${C}╚══════════════════════════════════════════════════════════════╝${N}"
    echo ""
    echo -e "${W}KOMUTLAR:${N}"
    echo "  eagle-guard start             Tüm korumaları başlat"
    echo "  eagle-guard stop              Tüm korumaları durdur"
    echo "  eagle-guard restart           Yeniden başlat"
    echo "  eagle-guard status            TUI durum ekranı"
    echo "  eagle-guard stats             JSON istatistik"
    echo "  eagle-guard block <IP>        IP engelle"
    echo "  eagle-guard unblock <IP>      IP engelini kaldır"
    echo "  eagle-guard report            Detaylı saldırı raporu"
    echo "  eagle-guard test-notify       Bildirim testi"
    echo "  eagle-guard geoip-update      GeoIP veritabanını güncelle"
    echo "  eagle-guard rules-mangle      Mangle/PREROUTING kuralları"
    echo "  eagle-guard rules-l4          L4 saldırı filtre kuralları"
    echo "  eagle-guard rules-l7          L7 uygulama filtre kuralları"
    echo "  eagle-guard rules-game        Game sunucu kuralları"
    echo "  eagle-guard rules-accept      Hızlı kabul zinciri kuralları"
    echo "  eagle-guard synproxy-stats    SYNPROXY istatistikleri"
    echo "  eagle-guard fail2ban-status   Fail2ban durumu"
    echo "  eagle-guard logs [N]          Son N log satırı"
    echo "  eagle-guard attack-log        Saldırı logları"
    echo "  eagle-guard waf-status        WAF durum özeti"
    echo "  eagle-guard game-on/off       Game koruması aç/kapat"
    echo "  eagle-guard help              Bu ekran"
    echo ""
    echo -e "${W}KATMANLAR:${N}"
    echo "  [MNG] mangle/PREROUTING  — Kernel seviyesi erken filtreleme"
    echo "  [SYP] SYNPROXY           — SYN flood (10x kapasite)"
    echo "  [L4]  EG_L4 zinciri      — SYN/ICMP/UDP/RST/Scan/Fragment"
    echo "  [L7]  EG_L7 zinciri      — HTTP/HTTPS flood, SSH/FTP brute force"
    echo "  [GM]  EG_GAME zinciri    — Oyun sunucusu UDP/TCP/RCON koruması"
    echo "  [WAF] Nginx+ModSecurity  — SQLi/XSS/LFI/RCE/Bot tespiti"
    echo ""
    echo -e "${W}KONFİGÜRASYON:${N} /opt/eagle-guard/config/eagle.conf"
    echo "  L7_HTTP_CONN=100          HTTP/HTTPS IP başına max bağlantı"
    echo "  L7_HTTP_RATE=80           HTTP/HTTPS IP başına yeni bağlantı/sn"
    echo "  L7_SSH_RATE=6             SSH IP başına max deneme/dak"
    echo "  GEOIP_ENABLED=yes"
    echo "  GEOIP_BLOCK_COUNTRIES=\"CN RU KP\""
    echo "  SYNPROXY_ENABLED=yes"
    echo "  SURICATA_ENABLED=yes      SURICATA_MODE=ips|ids"
    echo "  DISCORD_WEBHOOK=https://discord.com/api/webhooks/..."
    echo "  TELEGRAM_BOT=token        TELEGRAM_CHAT=chat_id"
}


tui() {
    while true; do
        clear
        local iface; iface=$(ip route 2>/dev/null|awk '/default/{print $5;exit}')
        local blk; blk=$(iptables -L EG_L4 -n 2>/dev/null|grep -c "^DROP"||echo 0)
        local mblk; mblk=$(iptables -t mangle -L EG_MANGLE -n 2>/dev/null|grep -c "^DROP"||echo 0)
        local conn; conn=$(ss -tn state established 2>/dev/null|wc -l)
        local cpu; cpu=$(awk '{printf "%.0f%%",$1*100/'"$(nproc 2>/dev/null||echo 1)"'}' /proc/loadavg)
        local mem; mem=$(free 2>/dev/null|awk '/Mem:/{printf "%.0f%%",$3/$2*100}')
        local bps; bps=$(python3 -c "import json;d=json.load(open('$STATS'));print(d.get('net',{}).get('bps_in',0))" 2>/dev/null||echo 0)
        local pps; pps=$(python3 -c "import json;d=json.load(open('$STATS'));print(d.get('net',{}).get('pps_in',0))" 2>/dev/null||echo 0)
        local f2b; f2b=$(python3 -c "import json;d=json.load(open('$STATS'));print(d.get('fail2ban',{}).get('banned',0))" 2>/dev/null||echo 0)
        # SYNPROXY istatistikleri
        local sp_syn sp_est
        sp_syn=$(awk '{print $1}' /proc/net/stat/synproxy 2>/dev/null|tail -1||echo 0)
        sp_est=$(awk '{print $3}' /proc/net/stat/synproxy 2>/dev/null|tail -1||echo 0)
        # L7 istatistikleri (EG_L7 zincirinden)
        local l7_http_cnt l7_ssh_cnt
        l7_http_cnt=$(iptables -L EG_L7 -nvx 2>/dev/null|awk '/EG-L7-HTTP/{s+=$1}END{print s+0}')
        l7_ssh_cnt=$(iptables  -L EG_L7 -nvx 2>/dev/null|awk '/EG-SSH-BF/{s+=$1}END{print s+0}')
        echo -e "${W}"
        echo "  ╔══════════════════════════════════════════════════════════════════════╗"
        echo "  ║  🦅  EAGLE GUARD v7.2  —  Enterprise DDoS Protection Engine         ║"
        echo "  ╠══════════════════════════════════════════════════════════════════════╣"
        printf "  ║  %-36s  %-33s║\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$(hostname) — ${iface:-eth0}"
        echo "  ╠══════════════════════════════════════════════════════════════════════╣"
        printf "  ║  ${G}AKTİF${N}  mangle:${Y}%-4s${N} ipt:${R}%-4s${N} f2b:${Y}%-4s${N} conn:${C}%-5s${N} cpu:${Y}%-5s${N} ram:${Y}%-5s${N}║\n" \
            "$mblk" "$blk" "$f2b" "$conn" "$cpu" "$mem"
        printf "  ║  IN: $(echo $bps|awk '{printf "%.2f MB/s",$1/1048576}')  PPS: $pps  SYNPROXY: SYN=$sp_syn EST=$sp_est%-18s║\n" ""
        echo "  ╠══════════════════════════════════════════════════════════════════════╣"
        echo -e "  ║  ${C}[MNG]${N} mangle/PREROUTING ✓  TTL ✓  MSS ✓  BadFlags ✓  Bogon ✓      ║"
        echo -e "  ║  ${G}[SYP]${N} SYNPROXY ✓  (10x SYN kapasite)                              ║"
        echo -e "  ║  ${C}[L4]${N}  SYN ✓  ICMP ✓  FRAG ✓  UDP/RST ✓  Scan ✓  ConnLimit ✓      ║"
        echo -e "  ║  ${R}[L7]${N}  HTTP flood:${Y}${l7_http_cnt}${N}  SSH brute:${Y}${l7_ssh_cnt}${N}  HTTPS/FTP/SMTP ✓              ║"
        echo -e "  ║  ${Y}[GEO]${N} GeoIP: $([ "$GEOIP_ENABLED" = "yes" ] && echo "AKTİF ($GEOIP_BLOCK_COUNTRIES)" || echo "Devre Dışı")$(printf '%*s' $((27-${#GEOIP_BLOCK_COUNTRIES})) '')║"
        echo -e "  ║  ${R}[IDS]${N} Suricata: $([ "$SURICATA_ENABLED" = "yes" ] && echo "$SURICATA_MODE modu" || echo "Devre Dışı")   [F2B] Fail2ban ✓              ║"
        echo -e "  ║  ${G}[GM]${N}  UDP Flood ✓  TCP ✓  RCON ✓  TinyUDP ✓  [WAF] Nginx+ModSec  ║"
        echo "  ╠══════════════════════════════════════════════════════════════════════╣"
        echo "  ║  Web: http://$(hostname -I 2>/dev/null|awk '{print $1}')/eagle-guard/  [Q] Çıkış          ║"
        echo -e "  ║  ${Y}Powered By Creart Cloud${N}$(printf '%*s' 47 '')║"
        echo -e "  ╚══════════════════════════════════════════════════════════════════════╝${N}"
        read -t 4 -n 1 k 2>/dev/null
        [[ "$k" == "q" || "$k" == "Q" ]] && break
    done
}


collect() {
    local iface; iface=$(ip route 2>/dev/null | awk '/default/{print $5;exit}')
    [[ -z "$iface" ]] && iface=eth0
    local rx_b tx_b rx_p tx_p
    rx_b=$(cat /sys/class/net/$iface/statistics/rx_bytes   2>/dev/null||echo 0)
    tx_b=$(cat /sys/class/net/$iface/statistics/tx_bytes   2>/dev/null||echo 0)
    rx_p=$(cat /sys/class/net/$iface/statistics/rx_packets 2>/dev/null||echo 0)
    tx_p=$(cat /sys/class/net/$iface/statistics/tx_packets 2>/dev/null||echo 0)

    local prx ptx prxp ptxp
    prx=$(python3  -c "import json;d=json.load(open('$STATS'));print(d.get('net',{}).get('bytes_in',0))"  2>/dev/null||echo 0)
    ptx=$(python3  -c "import json;d=json.load(open('$STATS'));print(d.get('net',{}).get('bytes_out',0))" 2>/dev/null||echo 0)
    prxp=$(python3 -c "import json;d=json.load(open('$STATS'));print(d.get('net',{}).get('pkts_in',0))"  2>/dev/null||echo 0)
    ptxp=$(python3 -c "import json;d=json.load(open('$STATS'));print(d.get('net',{}).get('pkts_out',0))" 2>/dev/null||echo 0)

    local bps_in bps_out pps_in pps_out
    bps_in=$(( (rx_b-prx)/INTERVAL )); bps_out=$(( (tx_b-ptx)/INTERVAL ))
    pps_in=$(( (rx_p-prxp)/INTERVAL )); pps_out=$(( (tx_p-ptxp)/INTERVAL ))
    for v in bps_in bps_out pps_in pps_out; do [[ ${!v} -lt 0 ]] && eval "$v=0"; done

    local cpu; cpu=$(awk '{printf "%.1f",$1*100/'"$(nproc 2>/dev/null||echo 1)"'}' /proc/loadavg 2>/dev/null||echo 0)
    local mem; mem=$(free 2>/dev/null|awk '/Mem:/{printf "%.1f",$3/$2*100}'||echo 0)
    local conn; conn=$(ss -tn state established 2>/dev/null|wc -l||echo 0)
    local uptime=0
    uptime=$(python3 -c "
import json,datetime
try:
    d=json.load(open('$STATS'))
    st=d.get('start_time','')
    if st:
        from datetime import timezone
        s=datetime.datetime.fromisoformat(st.replace('Z','+00:00'))
        print(int((datetime.datetime.now(timezone.utc)-s).total_seconds()))
    else: print(0)
except: print(0)" 2>/dev/null||echo 0)

    # Anomali tespiti
    anomaly_detect "$pps_in" "$bps_in" "$conn"

    # iptables sayaçları (OPTIMIZE: birleştirilmiş sorgu)
    local l4_syn l4_icmp l4_xmas l4_null l4_frag l4_scan l4_udp
    local l7_http l7_https l7_ssh
    local g_udp g_tcp g_rcon
    local mng_total sp_data blk f2b_cnt

    # Tek iptables call yerine birden fazla zinciri cache'le
    local ipt_l4; ipt_l4=$(iptables -L EG_L4 -nvx 2>/dev/null)
    local ipt_l7; ipt_l7=$(iptables -L EG_L7 -nvx 2>/dev/null)
    local ipt_game; ipt_game=$(iptables -L EG_GAME -nvx 2>/dev/null)
    local ipt_mng; ipt_mng=$(iptables -t mangle -L EG_MANGLE -nvx 2>/dev/null)

    l4_syn=$(echo "$ipt_l4"|awk '/EG-L4-SYN/{s+=$1}END{print s+0}')
    l4_icmp=$(echo "$ipt_l4"|awk '/EG-L4-ICMP/{s+=$1}END{print s+0}')
    l4_xmas=$(echo "$ipt_l4"|awk '/EG-L4-XMAS/{s+=$1}END{print s+0}')
    l4_null=$(echo "$ipt_l4"|awk '/EG-L4-NULL/{s+=$1}END{print s+0}')
    l4_frag=$(echo "$ipt_l4"|awk '/EG-L4-FRAG/{s+=$1}END{print s+0}')
    l4_scan=$(echo "$ipt_l4"|awk '/EG-L4-SCAN/{s+=$1}END{print s+0}')
    l4_udp=$(echo "$ipt_l4"|awk '/EG-L4-UDP/{s+=$1}END{print s+0}')
    l7_http=$(echo "$ipt_l7"|awk '/EG-L7-HTTP-/{s+=$1}END{print s+0}')
    l7_https=$(echo "$ipt_l7"|awk '/EG-L7-HTTPS-/{s+=$1}END{print s+0}')
    l7_ssh=$(echo "$ipt_l7"|awk '/EG-SSH-BF/{s+=$1}END{print s+0}')
    g_udp=$(echo "$ipt_game"|awk '/EG-GAME-UDP/{s+=$1}END{print s+0}')
    g_tcp=$(echo "$ipt_game"|awk '/EG-GAME-TCP/{s+=$1}END{print s+0}')
    g_rcon=$(echo "$ipt_game"|awk '/EG-GAME-RCON/{s+=$1}END{print s+0}')
    mng_total=$(echo "$ipt_mng"|awk 'NR>2{s+=$1}END{print s+0}')
    blk=$(echo "$ipt_l4"|grep -c "^DROP"||echo 0)
    f2b_cnt=$(fail2ban-client status 2>/dev/null|\
        grep -oP 'Currently banned:\s*\K\d+'|awk '{s+=$1}END{print s+0}'||echo 0)
    sp_data=$(cat /proc/net/stat/synproxy 2>/dev/null|tail -1||echo "0 0 0 0 0 0")

    # Kernel log'dan autoblock (OPTIMIZE: sadece son satırları oku)
    if [[ "$AUTO_BLOCK" == "yes" ]]; then
        for logf in /var/log/kern.log /var/log/syslog; do
            [[ -r "$logf" ]] || continue
            tail -200 "$logf" 2>/dev/null|grep "EG-"|\
                grep -oP 'SRC=\K[\d.]+' |sort|uniq -c|sort -rn|\
                head -50|\
                while read -r cnt ip; do
                    [[ "$cnt" -ge "$AUTOBLOCK_HITS" ]] && \
                        ip_block "$ip" "auto:${cnt}hits" L4 2>/dev/null
                done
        done
    fi

    local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    python3 - <<PY 2>/dev/null
import json
f="$TRAFFIC"
try: d=json.load(open(f))
except: d={"points":[]}
d["points"].append({
    "t":"$ts","unix":$(date +%s),
    "bps_in":$bps_in,"bps_out":$bps_out,"pps_in":$pps_in,"pps_out":$pps_out,
    "bytes_in":$rx_b,"bytes_out":$tx_b,"conn":$conn,"cpu":$cpu
})
d["points"]=d["points"][-240:]
json.dump(d,open(f,"w"))
PY
    python3 - <<PY 2>/dev/null
import json
f="$STATS"
try: d=json.load(open(f))
except: d={}
d.update({
  "status":"active","last_update":"$ts","interface":"$iface",
  "net":{"bps_in":$bps_in,"bps_out":$bps_out,"pps_in":$pps_in,"pps_out":$pps_out,
         "bytes_in":$rx_b,"bytes_out":$tx_b,"pkts_in":$rx_p,"pkts_out":$tx_p,
         "rx_mb":round($rx_b/1048576,2),"tx_mb":round($tx_b/1048576,2)},
  "mangle":{"total":$mng_total},
  "l4":{"syn":$l4_syn,"icmp":$l4_icmp,"xmas":$l4_xmas,
        "null":$l4_null,"frag":$l4_frag,"scan":$l4_scan,"udp":$l4_udp,
        "total":$l4_syn+$l4_icmp+$l4_xmas+$l4_null+$l4_frag},
  "l7":{"http":$l7_http,"https":$l7_https,"ssh":$l7_ssh,
        "total":$l7_http+$l7_https+$l7_ssh},
  "game":{"udp_flood":$g_udp,"tcp_flood":$g_tcp,"rcon":$g_rcon,
          "total":$g_udp+$g_tcp+$g_rcon},
  "fail2ban":{"banned":$f2b_cnt},
  "sys":{"cpu":$cpu,"mem":$mem,"conn":$conn,"uptime":$uptime},
  "blocked_rules":$blk
})
json.dump(d,open(f,"w"))
PY
}


# ── Ana komutlar ──────────────────────────────────────────────────────
case "${1:-help}" in
    start)
        [[ -f "$PID" ]] && kill -0 "$(cat $PID)" 2>/dev/null && \
            { echo -e "${Y}Zaten çalışıyor (PID: $(cat $PID))${N}"; exit 0; }
        load_conf; setup
        kernel_harden
        apply_rules       # mangle_apply() + EG_ACCEPT + EG_L4 + EG_L7 + EG_GAME
        synproxy_apply    # SYNPROXY (varsayılan devre dışı, config'den açılır)
        echo $$ > "$PID"
        python3 -c "
import json,datetime
f='$STATS'
try: d=json.load(open(f))
except: d={}
d['status']='active'
d['start_time']=datetime.datetime.utcnow().isoformat()+'Z'
json.dump(d,open(f,'w'))" 2>/dev/null || true
        log OK "Eagle Guard v7.2 başlatıldı (PID:$$) — SSH+Web kesintisiz"
        _host=$(hostname 2>/dev/null || echo "?")
        _ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        _uptime=$(uptime -p 2>/dev/null || echo "?")
        notify "system" "🦅 Eagle Guard Başlatıldı" \
"**Durum:** ✅ Aktif
**Host:** \`${_host}\` (\`${_ip}\`)
**Uptime:** ${_uptime}
**Katmanlar:** L4 · L7 · Game · XDP (config'e göre)
**SSH / Web:** kesintisiz korunuyor" "low"
        report_loop &
        # OPTIMIZE: load_conf'u loop'tan çıkardık — sadece startup'ta yükleniyor
        # Config değişiklikleri manuel restart gerektirir (system reload)
        while true; do collect; sleep "$INTERVAL"; done
        ;;
    stop)
        load_conf; setup
        rules_remove; kernel_reset
        python3 -c "
import json
try:
    d=json.load(open('$STATS')); d['status']='inactive'
    json.dump(d,open('$STATS','w'))
except: pass" 2>/dev/null || true
        _host=$(hostname 2>/dev/null || echo "?")
        notify "system" "🛑 Eagle Guard Durduruldu" \
"**Durum:** ⛔ İnaktif
**Host:** \`${_host}\`
**Not:** Koruma devre dışı — DDoS saldırılarına açık" "medium"
        kill "$(cat $PID 2>/dev/null)" 2>/dev/null || true
        rm -f "$PID"
        log OK "Eagle Guard durduruldu"
        ;;
    restart)
        load_conf; setup
        _host=$(hostname 2>/dev/null || echo "?")
        notify "system" "🔄 Eagle Guard Yeniden Başlatılıyor" \
"**Host:** \`${_host}\`
**Sebep:** manuel/config değişikliği
Servis 2 saniye içinde durdurulup tekrar başlayacak" "low"
        "$0" stop
        sleep 2
        exec "$0" start
        ;;
    status)    load_conf; setup; tui ;;
    block)
        [[ -z "$2" ]] && { show_help; exit 1; }
        load_conf; setup; ip_block "$2" "${3:-cli}" "${4:-L4}" ;;
    unblock)
        [[ -z "$2" ]] && { show_help; exit 1; }
        load_conf; setup; ip_unblock "$2" cli ;;
    stats)     python3 -m json.tool "$STATS" 2>/dev/null ;;
    report)    load_conf; setup; generate_report ;;
    tls-diag)
        echo "=== TLS / HTTPS Çıkış Teşhisi ==="
        echo "-- OpenSSL sürümü --"
        openssl version 2>&1 || echo "openssl yok"
        echo
        echo "-- discord.com TCP bağlantı --"
        timeout 5 bash -c 'cat </dev/tcp/discord.com/443 &>/dev/null' && echo "TCP 443 OK" || echo "TCP 443 FAIL"
        echo
        echo "-- curl TLS 1.3 (varsayılan) --"
        curl -sS -o /dev/null -w 'HTTP=%{http_code} rc=%{exitcode} time=%{time_total}s\n' \
             --max-time 8 https://discord.com/api/v10/gateway 2>&1 | head -3
        echo
        echo "-- curl TLS 1.2 zorla --"
        curl -sS -o /dev/null -w 'HTTP=%{http_code} time=%{time_total}s\n' \
             --max-time 8 --tlsv1.2 --tls-max 1.2 --http1.1 \
             https://discord.com/api/v10/gateway 2>&1 | head -3
        echo
        echo "-- Diğer HTTPS hedefleri --"
        for url in https://www.google.com https://api.telegram.org https://cloudflare.com; do
            printf "  %-35s " "$url"
            curl -sS -o /dev/null -w 'HTTP=%{http_code} time=%{time_total}s\n' \
                 --max-time 6 "$url" 2>&1 | head -1
        done
        echo
        echo "-- OUTPUT firewall ilk 15 satır --"
        iptables -L OUTPUT -nv 2>&1 | head -15
        ;;
    test-notify)
        load_conf; setup
        echo "── Bildirim kanalları ──"
        echo "  DISCORD_WEBHOOK : $([[ -n "${DISCORD_WEBHOOK:-}" ]] && echo "ayarlı (${#DISCORD_WEBHOOK} char)" || echo "BOŞ")"
        echo "  TELEGRAM_BOT    : $([[ -n "${TELEGRAM_BOT:-}"    ]] && echo "ayarlı" || echo "BOŞ")"
        echo "  EMAIL_TO        : $([[ -n "${EMAIL_TO:-}"        ]] && echo "ayarlı" || echo "BOŞ")"
        echo
        # İnternet/Discord erişim ön testi
        if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
            echo "── curl ön testi: https://discord.com ──"
            if curl -sS -4 -o /dev/null -w 'HTTP=%{http_code} time=%{time_total}s\n' \
                    --connect-timeout 5 --max-time 8 https://discord.com/api/v10/gateway 2>&1; then
                echo "  ✓ discord.com erişilebilir"
            else
                echo "  ✗ discord.com erişilemez — sunucunun HTTPS çıkışını kontrol edin"
            fi
            echo
        fi
        echo "── Bildirim gönderiliyor ──"
        if notify "system" "🧪 Test Bildirimi" \
                  "Eagle Guard v7.2 bildirim testi — $(date)" "low"; then
            rc=$?
        else
            rc=$?
        fi
        echo
        echo "Tamamlandı. Ayrıntı için: tail /tmp/eg-discord.err /tmp/eg-discord.out"
        ;;
    geoip-update)   load_conf; setup; geoip_update ;;
    rules-mangle)   iptables -t mangle -L EG_MANGLE -nvx 2>/dev/null ;;
    rules-l4)       iptables -L EG_L4     -nvx 2>/dev/null ;;
    rules-l7)       iptables -L EG_L7     -nvx 2>/dev/null ;;
    rules-game)     iptables -L EG_GAME   -nvx 2>/dev/null ;;
    rules-accept)   iptables -L EG_ACCEPT -nvx 2>/dev/null ;;
    waf-status)
        load_conf
        if [ -f /opt/eagle-guard/waf/scripts/waf-ctl.sh ]; then
            bash /opt/eagle-guard/waf/scripts/waf-ctl.sh status
        else
            echo "WAF kurulu değil. Kurmak için: sudo bash /opt/eagle-guard/waf/scripts/install-waf.sh"
        fi
        ;;
    synproxy-stats)
        echo "=== SYNPROXY İstatistikleri ==="
        cat /proc/net/stat/synproxy 2>/dev/null || echo "SYNPROXY verisi yok"
        ;;
    fail2ban-status)
        command -v fail2ban-client >/dev/null 2>&1 && \
            fail2ban-client status || echo "Fail2ban kurulu değil"
        ;;
    logs)       tail -"${2:-100}" "$LOG" 2>/dev/null ;;
    attack-log) tail -"${2:-100}" "$LOG_ATTACK" 2>/dev/null ;;
    game-on)
        load_conf; setup
        iptables -D INPUT -j EG_GAME 2>/dev/null
        iptables -F EG_GAME 2>/dev/null; iptables -X EG_GAME 2>/dev/null
        iptables -N EG_GAME; iptables -I INPUT 6 -j EG_GAME
        GAME_ENABLED=yes; [[ -f "$CONF" ]] && source "$CONF" 2>/dev/null || true
        iptables -A EG_GAME -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        IFS=',' read -ra UPORTS <<< "$GAME_PORTS_UDP"
        for port in "${UPORTS[@]}"; do
            port=$(echo "$port"|tr -d ' '); [[ -z "$port" ]] && continue
            iptables -A EG_GAME -p udp --dport "$port" \
                -m hashlimit --hashlimit-name "gu${port}" \
                --hashlimit-above "${GAME_UDP_PPS}/sec" \
                --hashlimit-mode srcip --hashlimit-burst "$GAME_UDP_BURST" -j DROP 2>/dev/null
        done
        log OK "Game koruması açıldı"
        ;;
    game-off)
        iptables -D INPUT -j EG_GAME 2>/dev/null
        iptables -F EG_GAME 2>/dev/null; iptables -X EG_GAME 2>/dev/null
        log OK "Game koruması kapatıldı"
        ;;
    help|--help|-h) show_help ;;
    *) echo "Bilinmeyen: $1"; show_help ;;
esac
