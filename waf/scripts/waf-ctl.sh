#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════
#  Eagle Guard WAF kontrol scripti (v7.4)
#    rebuild    — custom rules + geo + ti + uam include'larını yeniden üret
#    ti-sync    — threat intel feed'lerini indir
#    geo-sync   — GeoIP DB güncelle
#    mode <X>   — WAF_MODE=block|detect ayarla
#    uam <y/n>  — Under Attack Mode aç/kapat
#    reload     — nginx reload
#    status     — özet durum
#    test       — temel blok testleri
# ═════════════════════════════════════════════════════════════════
set -e
WAF=/opt/eagle-guard/waf
CONF="$WAF/waf.conf"
[[ -f "$CONF" ]] && source "$CONF" || { echo "waf.conf yok"; exit 1; }

cmd="${1:-help}"

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

rebuild_custom() {
    log "Custom kurallar üretiliyor..."
    local out="$WAF/rules/eagle-custom.conf"
    cat > "$out" << 'HEADER'
# Eagle Guard özel kuralları (JSON'dan üretildi, elle düzenlemeyin)
# Dashboard → WAF → Kural Yönetimi ile düzenleyin
HEADER
    python3 - "$WAF/rules/custom.json" >> "$out" << 'PY'
import json,sys,re
try: d=json.load(open(sys.argv[1]))
except Exception as e:
    print(f"# hata: {e}"); sys.exit(0)
rid_base=100000
for i,r in enumerate(d.get("rules",[])):
    if not r.get("enabled"): continue
    rid = rid_base+i
    name = r.get("name","").replace('"','\\"')
    action = r.get("action","block")
    m = r.get("match",{})
    mtype = m.get("type","path")
    pattern = m.get("pattern","")
    # ModSec action mapping
    if action == "block":
        act = f'phase:1,id:{rid},t:none,deny,status:403,log,msg:"EG-CUSTOM: {name}"'
    elif action == "challenge":
        # challenge: 307 redirect to __eg_challenge?r=<orig>
        act = f'phase:1,id:{rid},t:none,redirect:/__eg_challenge?r=%{{REQUEST_URI}},log,msg:"EG-CHALLENGE: {name}"'
    elif action == "log":
        act = f'phase:1,id:{rid},t:none,pass,log,msg:"EG-LOG: {name}"'
    else:
        continue
    var_map = {
        "path":   "REQUEST_URI",
        "query":  "QUERY_STRING",
        "ua":     "REQUEST_HEADERS:User-Agent",
        "method": "REQUEST_METHOD",
        "body":   "REQUEST_BODY",
        "header": "REQUEST_HEADERS",
        "host":   "REQUEST_HEADERS:Host",
    }
    var = var_map.get(mtype, "REQUEST_URI")
    # Regex escape
    print(f'SecRule {var} "@rx {pattern}" "{act}"')
PY
    log "→ $out"
}

rebuild_geo() {
    log "GeoIP kuralları üretiliyor..."
    local map="$WAF/data/geo-map.conf"
    local enforce="$WAF/data/geo-enforce.conf"
    : > "$map"
    : > "$enforce"
    if [[ "$GEO_ENABLED" != "yes" ]]; then
        echo "# GeoIP kapalı" > "$enforce"
        return
    fi
    local countries="${GEO_COUNTRIES:-}"
    IFS=',' read -ra CS <<< "$countries"
    if [[ "$GEO_MODE" == "whitelist" ]]; then
        # whitelist modunda listedekiler 0, diğerleri 1
        echo "default 1;" > "$map"
        for c in "${CS[@]}"; do c=$(echo "$c"|tr -d ' '); [[ -n "$c" ]] && echo "$c 0;" >> "$map"; done
    else
        # blacklist
        echo "default 0;" > "$map"
        for c in "${CS[@]}"; do c=$(echo "$c"|tr -d ' '); [[ -n "$c" ]] && echo "$c 1;" >> "$map"; done
    fi
    cat > "$enforce" << 'NG'
if ($eg_geo_deny = 1) {
    return 451 "Blocked by Eagle Guard (GeoIP policy)";
}
NG
    log "→ $map ($(wc -l < "$map") ülke)"
}

ti_sync() {
    log "Threat Intel feed sync..."
    mkdir -p "$WAF/data/ti"
    local feeds="${TI_FEEDS:-spamhaus-drop,firehol-level1,tor-exits}"
    : > "$WAF/data/ti/combined.txt"
    IFS=',' read -ra F <<< "$feeds"
    for f in "${F[@]}"; do
        f=$(echo "$f"|tr -d ' ')
        local url=""
        case "$f" in
            spamhaus-drop)    url="https://www.spamhaus.org/drop/drop.txt" ;;
            spamhaus-edrop)   url="https://www.spamhaus.org/drop/edrop.txt" ;;
            firehol-level1)   url="https://iplists.firehol.org/files/firehol_level1.netset" ;;
            firehol-level2)   url="https://iplists.firehol.org/files/firehol_level2.netset" ;;
            tor-exits)        url="https://check.torproject.org/exit-addresses" ;;
            emergingthreats)  url="https://rules.emergingthreats.net/blockrules/compromised-ips.txt" ;;
            *) continue ;;
        esac
        log "  ↓ $f"
        curl -fsSL --max-time 30 "$url" -o "$WAF/data/ti/$f.raw" 2>/dev/null || { log "  ✗ $f indirilemedi"; continue; }
        # Parse: IP veya IP/CIDR çıkar
        grep -oE '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' "$WAF/data/ti/$f.raw" >> "$WAF/data/ti/combined.txt" || true
        # Tor exit-addresses özel format
        [[ "$f" == "tor-exits" ]] && grep -oE 'ExitAddress ([0-9]{1,3}\.){3}[0-9]{1,3}' "$WAF/data/ti/$f.raw" | awk '{print $2}' >> "$WAF/data/ti/combined.txt" || true
    done
    sort -u "$WAF/data/ti/combined.txt" -o "$WAF/data/ti/combined.txt"
    local cnt=$(wc -l < "$WAF/data/ti/combined.txt")
    log "  toplam $cnt benzersiz IP/CIDR"

    # Nginx deny formatına çevir
    local out="$WAF/data/ti-deny.conf"
    : > "$out"
    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        echo "deny $ip;"
    done < "$WAF/data/ti/combined.txt" > "$out"
    log "→ $out"

    # Ayrıca iptables TI_AUTO_BLOCK=yes ise ipset'e de ekle
    if [[ "${TI_AUTO_BLOCK:-no}" == "yes" ]] && command -v ipset >/dev/null 2>&1; then
        ipset create eagle_ti hash:net 2>/dev/null || ipset flush eagle_ti
        while IFS= read -r ip; do
            [[ -z "$ip" ]] && continue
            ipset add eagle_ti "$ip" 2>/dev/null || true
        done < "$WAF/data/ti/combined.txt"
        iptables -C INPUT -m set --match-set eagle_ti src -j DROP 2>/dev/null || \
            iptables -I INPUT 1 -m set --match-set eagle_ti src -j DROP
        log "  iptables ipset eagle_ti aktif"
    fi
}

rebuild_uam() {
    local out="$WAF/data/uam-flag.conf"
    if [[ "$UAM_ENABLED" == "yes" ]]; then
        cat > "$out" << NG
# Under Attack Mode AÇIK — doğrulanmamış kullanıcıları challenge'a yönlendir
if (\$eg_uam_pass = 0) {
    if (\$request_uri !~ ^/(__eg_challenge|__eg_verify|favicon\\.ico)) {
        return 307 /__eg_challenge?r=\$request_uri;
    }
}
NG
    else
        echo "# UAM kapalı" > "$out"
    fi
}

geo_sync() {
    log "GeoIP DB indiriliyor..."
    local url="https://raw.githubusercontent.com/P3TERX/GeoLite.mmdb/download/GeoLite2-Country.mmdb"
    curl -fsSL --max-time 60 -o "$WAF/data/GeoLite2-Country.mmdb.new" "$url" \
        && mv "$WAF/data/GeoLite2-Country.mmdb.new" "$WAF/data/GeoLite2-Country.mmdb" \
        && log "✓ GeoIP DB güncellendi ($(stat -c%s "$WAF/data/GeoLite2-Country.mmdb") bytes)" \
        || log "✗ GeoIP indirilemedi"
}

set_mode() {
    local m="$1"
    case "$m" in
        block|detect) ;;
        *) echo "Geçersiz mod: $m (block|detect)"; exit 1 ;;
    esac
    sed -i "s/^WAF_MODE=.*/WAF_MODE=$m/" "$CONF"
    # ModSec'e yansıt
    if [[ -f /etc/nginx/modsec/modsecurity.conf ]]; then
        if [[ "$m" == "block" ]]; then
            sed -i 's/^SecRuleEngine .*/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf
        else
            sed -i 's/^SecRuleEngine .*/SecRuleEngine DetectionOnly/' /etc/nginx/modsec/modsecurity.conf
        fi
    fi
    log "WAF mode: $m"
    reload_nginx
}

set_uam() {
    local v="$1"
    case "$v" in yes|y|on|1) v=yes ;; *) v=no ;; esac
    sed -i "s/^UAM_ENABLED=.*/UAM_ENABLED=$v/" "$CONF"
    export UAM_ENABLED="$v"
    rebuild_uam
    reload_nginx
    log "Under Attack Mode: $v"
}

reload_nginx() {
    nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null && log "nginx reloaded" \
        || log "✗ nginx config hatası — nginx -t ile kontrol"
}

status() {
    echo "=== Eagle Guard WAF Durum ==="
    echo "  WAF_ENABLED     : $WAF_ENABLED"
    echo "  WAF_MODE        : $WAF_MODE"
    echo "  WAF_LISTEN_PORT : $WAF_LISTEN_PORT"
    echo "  UPSTREAM        : $WAF_UPSTREAM"
    echo "  PARANOIA        : $WAF_PARANOIA"
    echo "  UAM             : $UAM_ENABLED"
    echo "  GeoIP           : $GEO_ENABLED ($GEO_MODE: $GEO_COUNTRIES)"
    echo "  TI Feeds        : $TI_FEEDS"
    echo
    echo "  Custom rules    : $(python3 -c "import json;print(sum(1 for r in json.load(open('$WAF/rules/custom.json'))['rules'] if r.get('enabled')))" 2>/dev/null || echo 0) aktif"
    echo "  TI IP blocks    : $(wc -l < "$WAF/data/ti/combined.txt" 2>/dev/null || echo 0)"
    echo "  Audit log       : $(wc -l < "$WAF/logs/audit.log" 2>/dev/null || echo 0) satır"
    echo
    if command -v nginx >/dev/null; then
        echo "  Nginx           : $(systemctl is-active nginx 2>/dev/null)"
        echo "  WAF port dinle  : $(ss -tln 2>/dev/null | grep ":$WAF_LISTEN_PORT " | head -1 || echo "pasif")"
    fi
}

test_waf() {
    local host="http://127.0.0.1:$WAF_LISTEN_PORT"
    echo "=== WAF test (beklenen: 403/444) ==="
    for t in \
        "SQLi:?id=1'%20OR%201=1--" \
        "XSS:?x=<script>alert(1)</script>" \
        "LFI:?f=../../../etc/passwd" \
        "RCE:?c=;cat%20/etc/passwd" \
        "UA-bot:-H User-Agent:sqlmap/1.0"; do
        name="${t%%:*}"; extra="${t#*:}"
        if [[ "$extra" == -H* ]]; then
            code=$(curl -s -o /dev/null -w '%{http_code}' -A sqlmap/1.0 "$host/" 2>/dev/null || echo 000)
        else
            code=$(curl -s -o /dev/null -w '%{http_code}' "$host/$extra" 2>/dev/null || echo 000)
        fi
        printf "  %-8s %s → HTTP %s\n" "$name" "$extra" "$code"
    done
}

case "$cmd" in
    rebuild)    rebuild_custom; rebuild_geo; rebuild_uam; reload_nginx ;;
    ti-sync)    ti_sync; reload_nginx ;;
    geo-sync)   geo_sync ;;
    mode)       set_mode "$2" ;;
    uam)        set_uam "$2" ;;
    reload)     reload_nginx ;;
    status)     status ;;
    test)       test_waf ;;
    help|*)
        cat << H
Eagle Guard WAF kontrol komutları:
  rebuild          Custom rules + Geo + UAM include dosyalarını üret + reload
  ti-sync          Threat Intel feed'leri indir + uygula
  geo-sync         GeoLite2 DB güncelle
  mode <block|detect>   WAF modu
  uam <yes|no>     Under Attack Mode
  reload           nginx reload
  status           Durum özeti
  test             Yerel test (SQLi/XSS/LFI/RCE)
H
        ;;
esac
