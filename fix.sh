#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║   EAGLE GUARD — FIX / ONARIM SCRİPTİ                                ║
# ║   Mevcut kurulumu kontrol eder ve düzeltir                           ║
# ╚══════════════════════════════════════════════════════════════════════╝
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' N='\033[0m'
ok()   { echo -e "${G}  ✓${N} $*"; }
fix()  { echo -e "${Y}  🔧${N} $*"; }
err()  { echo -e "${R}  ✗${N} $*"; }
info() { echo -e "${C}  →${N} $*"; }

[[ $EUID -ne 0 ]] && { echo "sudo bash fix.sh gerekli"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${C}=== Eagle Guard Onarım Scripti ===${N}"
echo ""

# ── 1. Dizinler ───────────────────────────────────────────────────
info "Dizin kontrolü..."
for d in /opt/eagle-guard /opt/eagle-guard/scripts /opt/eagle-guard/data \
          /opt/eagle-guard/logs /opt/eagle-guard/config \
          /opt/eagle-guard/xdp /opt/eagle-guard/dpdk; do
    if [[ ! -d "$d" ]]; then
        mkdir -p "$d"; fix "Oluşturuldu: $d"
    else
        ok "Mevcut: $d"
    fi
done

# ── 2. eagle-guard.sh ─────────────────────────────────────────────
info "Script kontrolü..."
if [[ -f "$SCRIPT_DIR/scripts/eagle-guard.sh" ]]; then
    cp -f "$SCRIPT_DIR/scripts/eagle-guard.sh" /opt/eagle-guard/scripts/eagle-guard.sh
    chmod +x /opt/eagle-guard/scripts/eagle-guard.sh
    ln -sf /opt/eagle-guard/scripts/eagle-guard.sh /usr/local/bin/eagle-guard
    ok "Script güncellendi: /opt/eagle-guard/scripts/eagle-guard.sh"
else
    [[ -f /opt/eagle-guard/scripts/eagle-guard.sh ]] && ok "Script mevcut" || err "Script bulunamadı!"
fi

# XDP/DPDK dosyalarını senkronize et
if [[ -d "$SCRIPT_DIR/xdp" ]]; then
    cp -rf "$SCRIPT_DIR/xdp/"* /opt/eagle-guard/xdp/ 2>/dev/null
    chmod +x /opt/eagle-guard/xdp/*.sh 2>/dev/null || true
    ok "xdp/ senkronize edildi"
fi
if [[ -d "$SCRIPT_DIR/dpdk" ]]; then
    cp -rf "$SCRIPT_DIR/dpdk/"* /opt/eagle-guard/dpdk/ 2>/dev/null
    chmod +x /opt/eagle-guard/dpdk/*.sh 2>/dev/null || true
    ok "dpdk/ senkronize edildi"
fi

# BPF objesi yoksa build dene
if [[ -f /opt/eagle-guard/xdp/eagle_xdp.c ]] && [[ ! -f /opt/eagle-guard/xdp/eagle_xdp.o ]]; then
    info "BPF objesi yok, build deneniyor..."
    (cd /opt/eagle-guard/xdp && bash build.sh) >/dev/null 2>&1 && \
        ok "eagle_xdp.o üretildi" || fix "BPF build başarısız (bağımlılıklar eksik olabilir)"
fi

# ── 3. Data dosyaları ─────────────────────────────────────────────
info "Data dosyaları kontrolü..."
[[ ! -f /opt/eagle-guard/data/blocked.json ]] && \
    echo '{"blocked":[]}' > /opt/eagle-guard/data/blocked.json && fix "blocked.json oluşturuldu"
[[ ! -f /opt/eagle-guard/data/alerts.json ]] && \
    echo '{"alerts":[]}' > /opt/eagle-guard/data/alerts.json && fix "alerts.json oluşturuldu"
[[ ! -f /opt/eagle-guard/data/traffic.json ]] && \
    echo '{"points":[]}' > /opt/eagle-guard/data/traffic.json && fix "traffic.json oluşturuldu"
[[ ! -f /opt/eagle-guard/data/stats.json ]] && \
    echo '{"status":"inactive","net":{"bps_in":0,"bps_out":0,"pps_in":0,"pps_out":0},"l4":{},"l7":{},"sys":{"cpu":0,"mem":0,"conn":0,"uptime":0}}' \
    > /opt/eagle-guard/data/stats.json && fix "stats.json oluşturuldu"
[[ ! -f /opt/eagle-guard/config/whitelist.txt ]] && \
    printf "127.0.0.1\n::1\n" > /opt/eagle-guard/config/whitelist.txt && fix "whitelist.txt oluşturuldu"

# JSON dosyaları doğrula
for f in /opt/eagle-guard/data/*.json; do
    if ! python3 -m json.tool "$f" >/dev/null 2>&1; then
        fix "Bozuk JSON onarılıyor: $f"
        fname=$(basename "$f" .json)
        case $fname in
            blocked) echo '{"blocked":[]}' > "$f" ;;
            alerts)  echo '{"alerts":[]}' > "$f" ;;
            traffic) echo '{"points":[]}' > "$f" ;;
            stats)   echo '{"status":"inactive"}' > "$f" ;;
        esac
    fi
done
ok "Data dosyaları sağlıklı"

# ── 4. Web dosyaları ──────────────────────────────────────────────
info "Web dosyaları kontrolü..."
WEB=/var/www/html/eagle-guard

# Apache kurulu mu?
if ! command -v apache2 >/dev/null 2>&1; then
    fix "Apache2 kuruluyor..."
    apt-get install -y apache2 php libapache2-mod-php php-json -qq
fi

mkdir -p "$WEB"
mkdir -p "$WEB/api"

# index.php
if [[ -f "$SCRIPT_DIR/web/index.php" ]]; then
    cp -f "$SCRIPT_DIR/web/index.php" "$WEB/index.php"
    ok "index.php kopyalandı"
elif [[ ! -f "$WEB/index.php" ]]; then
    err "WEB/index.php eksik! $SCRIPT_DIR/web/index.php bulunamadı"
else
    ok "index.php mevcut (güncelleme atlandı)"
fi

# api/index.php
if [[ -f "$SCRIPT_DIR/web/api/index.php" ]]; then
    cp -f "$SCRIPT_DIR/web/api/index.php" "$WEB/api/index.php"
    ok "api/index.php kopyalandı"
elif [[ ! -f "$WEB/api/index.php" ]]; then
    err "API/index.php eksik! $SCRIPT_DIR/web/api/index.php bulunamadı"
else
    ok "api/index.php mevcut (güncelleme atlandı)"
fi

# ── 5. İzinler ────────────────────────────────────────────────────
info "İzinler düzenleniyor..."
chown -R www-data:www-data "$WEB"
chmod -R 755 "$WEB"

# data/logs için www-data izni
if command -v setfacl >/dev/null 2>&1; then
    setfacl -R -m u:www-data:rwx /opt/eagle-guard/data/ 2>/dev/null
    setfacl -R -m u:www-data:rx  /opt/eagle-guard/logs/ 2>/dev/null
    setfacl -R -m u:www-data:rwx /opt/eagle-guard/config/ 2>/dev/null
    setfacl    -m u:www-data:rw  /opt/eagle-guard/config/eagle.conf 2>/dev/null
    ok "ACL izinleri güncellendi (config: www-data RW)"
else
    chmod 777 /opt/eagle-guard/data/
    chmod 755 /opt/eagle-guard/logs/
    chmod 644 /opt/eagle-guard/data/*.json 2>/dev/null || true
    chmod o+w /opt/eagle-guard/data/*.json 2>/dev/null || true
    chmod 775 /opt/eagle-guard/config/ 2>/dev/null || true
    chmod 664 /opt/eagle-guard/config/eagle.conf 2>/dev/null || true
    chown root:www-data /opt/eagle-guard/config/eagle.conf 2>/dev/null || true
    ok "chmod izinleri güncellendi (config: www-data yazabilir)"
fi

# ── 6. Sudo ───────────────────────────────────────────────────────
info "Sudo izinleri kontrolü..."
if [[ ! -f /etc/sudoers.d/eagle-guard ]]; then
    fix "sudoers dosyası oluşturuluyor..."
fi
cat > /etc/sudoers.d/eagle-guard << 'SUDO'
# Eagle Guard sudo izinleri
Defaults:www-data !requiretty
www-data ALL=(root) NOPASSWD: /opt/eagle-guard/scripts/eagle-guard.sh
www-data ALL=(root) NOPASSWD: /sbin/iptables, /usr/sbin/iptables
www-data ALL=(root) NOPASSWD: /sbin/ip6tables, /usr/sbin/ip6tables
www-data ALL=(root) NOPASSWD: /usr/sbin/iptables-nft, /usr/sbin/iptables-legacy
www-data ALL=(root) NOPASSWD: /usr/sbin/nft, /usr/sbin/ipset
www-data ALL=(root) NOPASSWD: /bin/systemctl start eagle-guard, /bin/systemctl stop eagle-guard, /bin/systemctl restart eagle-guard, /bin/systemctl reload eagle-guard, /bin/systemctl status eagle-guard, /bin/systemctl is-active eagle-guard
www-data ALL=(root) NOPASSWD: /usr/bin/systemctl start eagle-guard, /usr/bin/systemctl stop eagle-guard, /usr/bin/systemctl restart eagle-guard, /usr/bin/systemctl reload eagle-guard, /usr/bin/systemctl status eagle-guard, /usr/bin/systemctl is-active eagle-guard
www-data ALL=(root) NOPASSWD: /bin/journalctl, /usr/bin/journalctl
www-data ALL=(root) NOPASSWD: /usr/sbin/ss, /bin/ss, /usr/bin/ss
www-data ALL=(root) NOPASSWD: /usr/sbin/bpftool, /usr/bin/bpftool
www-data ALL=(root) NOPASSWD: /usr/sbin/fail2ban-client
www-data ALL=(root) NOPASSWD: /opt/eagle-guard/xdp/eagle-xdp-loader.sh
www-data ALL=(root) NOPASSWD: /opt/eagle-guard/xdp/eagle-xdp-ctl.sh
www-data ALL=(root) NOPASSWD: /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh
SUDO
chmod 440 /etc/sudoers.d/eagle-guard
ok "sudoers güncellendi"

# Sudo test
SUDO_TEST=$(sudo -u www-data sudo -n /sbin/iptables -L INPUT -n 2>&1 | head -1 || echo "fail")
if echo "$SUDO_TEST" | grep -q "Chain\|policy\|target"; then
    ok "sudo www-data → iptables çalışıyor"
else
    fix "sudo test başarısız: $SUDO_TEST"
fi

# ── 7. Apache yapılandırması ──────────────────────────────────────
info "Apache yapılandırması kontrol ediliyor..."

# mod_php aktif mi?
a2enmod php* 2>/dev/null || true
a2enmod rewrite 2>/dev/null || true

# AllowOverride All
for conf in /etc/apache2/sites-available/000-default.conf \
            /etc/apache2/sites-enabled/000-default.conf; do
    if [[ -f "$conf" ]] && grep -q "AllowOverride None" "$conf" 2>/dev/null; then
        sed -i 's/AllowOverride None/AllowOverride All/g' "$conf"
        fix "AllowOverride None → All düzeltildi: $conf"
    fi
done

# Eagle Guard Apache conf
cat > /etc/apache2/conf-available/eagle-guard.conf << 'ACONF'
<Directory /var/www/html/eagle-guard>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    Require all granted
    DirectoryIndex index.php
</Directory>
ACONF
a2enconf eagle-guard 2>/dev/null || true

# .htaccess
cat > "$WEB/.htaccess" << 'HTA'
Options -Indexes
DirectoryIndex index.php
HTA

systemctl reload apache2 2>/dev/null || systemctl restart apache2 2>/dev/null
ok "Apache yeniden yüklendi"

# Apache test
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/eagle-guard/" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
    ok "HTTP test: 200 OK ✓"
elif [[ "$HTTP_CODE" == "403" ]]; then
    fix "HTTP 403 — izin sorunu düzeltiliyor..."
    chmod 755 "$WEB"
    chmod 644 "$WEB/index.php"
    systemctl reload apache2
elif [[ "$HTTP_CODE" == "500" ]]; then
    err "HTTP 500 — PHP hatası! Log: tail -20 /var/log/apache2/error.log"
else
    fix "HTTP $HTTP_CODE — Apache erişilemiyor (firewall/port sorunu olabilir)"
fi

# ── 8. API test ───────────────────────────────────────────────────
info "API endpoint testi..."
API_RESP=$(curl -s "http://localhost/eagle-guard/api/index.php?action=debug" 2>/dev/null | head -c 200)
if echo "$API_RESP" | grep -q '"ok":true'; then
    ok "API çalışıyor ✓"
else
    fix "API yanıtı: $API_RESP"
    # PHP syntax check
    php -l "$WEB/api/index.php" 2>&1 | head -3
fi

# ── 9. Servis durumu ──────────────────────────────────────────────
info "Eagle Guard servis kontrolü..."
if ! systemctl is-active eagle-guard --quiet 2>/dev/null; then
    fix "Servis başlatılıyor..."
    systemctl start eagle-guard 2>/dev/null || true
    sleep 2
fi
if systemctl is-active eagle-guard --quiet 2>/dev/null; then
    ok "Eagle Guard servisi aktif"
else
    fix "Servis başlatılamadı (iptables kurulu değil olabilir)"
    fix "Manuel deneme: sudo eagle-guard start"
fi

# ── Özet rapor ────────────────────────────────────────────────────
IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "SUNUCU_IP")
echo ""
echo -e "${C}═══════════════════════════════════════════════════${N}"
echo -e "${C} 📋 DURUM RAPORU${N}"
echo -e "${C}═══════════════════════════════════════════════════${N}"

check() {
    [[ $1 ]] && echo -e "  ${G}✓${N} $2" || echo -e "  ${R}✗${N} $2 — EKSİK/HATA"
}
check "$([ -f /opt/eagle-guard/scripts/eagle-guard.sh ] && echo y)" "eagle-guard.sh"
check "$([ -f /var/www/html/eagle-guard/index.php ] && echo y)"     "web/index.php"
check "$([ -f /var/www/html/eagle-guard/api/index.php ] && echo y)" "web/api/index.php"
check "$([ -f /etc/sudoers.d/eagle-guard ] && echo y)"              "sudoers"
check "$([ -w /opt/eagle-guard/data ] && echo y)"                   "data/ yazılabilir"
check "$(systemctl is-active apache2 --quiet 2>/dev/null && echo y)" "Apache2"
check "$(systemctl is-active eagle-guard --quiet 2>/dev/null && echo y)" "eagle-guard servisi"

echo ""
echo -e "  ${G}🌐 Web:${N} http://$IP/eagle-guard/"
echo -e "  ${G}🔍 Debug:${N} http://$IP/eagle-guard/api/index.php?action=debug"
echo -e "${C}═══════════════════════════════════════════════════${N}"
