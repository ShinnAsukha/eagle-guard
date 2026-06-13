#!/bin/bash
# Eagle Guard v7.2 — Otomatik Kurulum (XDP/eBPF + DPDK hazır)
# Kullanım: sudo bash install.sh
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' N='\033[0m'
ERRORS=0
LOG="/tmp/eagle-install-$(date +%Y%m%d-%H%M%S).log"

ok()   { echo -e "${G}  [OK]${N} $*";  echo "[OK] $*"  >> "$LOG"; }
info() { echo -e "${C}  [..]${N} $*";  echo "[..] $*"  >> "$LOG"; }
warn() { echo -e "${Y}  [!!]${N} $*";  echo "[!!] $*"  >> "$LOG"; }
fail() { echo -e "${R}  [XX]${N} $*";  echo "[XX] $*"  >> "$LOG"; ERRORS=$((ERRORS+1)); }
step() { echo -e "\n${W}━━━ $* ━━━${N}"; }

cp_f() {
    # cp_f kaynak hedef açıklama
    if [ ! -f "$1" ]; then fail "Kaynak yok: $1"; return 1; fi
    cp -f "$1" "$2" 2>>"$LOG" && ok "$3" || fail "Kopyalanamadı: $1 → $2"
}

SDIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

echo -e "\n${C}  ╔═══════════════════════════════════════════════════╗${N}"
echo -e "${W}  ║  🦅  Eagle Guard v7.2 — Kurulum                  ║${N}"
echo -e "${Y}  ║  Powered By Creart Cloud                         ║${N}"
echo -e "${C}  ╚═══════════════════════════════════════════════════╝${N}"
echo "  Kaynak: $SDIR | Log: $LOG"
echo ""

# Root
[ "$(id -u)" != "0" ] && { echo -e "${R}sudo bash install.sh gerekli${N}"; exit 1; }
ok "Root yetkisi var"

# Kaynak dosya kontrol
step "KAYNAK DOSYALAR"
MISS=0
for f in \
    "$SDIR/scripts/eagle-guard.sh" \
    "$SDIR/web/index.php" \
    "$SDIR/web/api/index.php" \
    "$SDIR/systemd/eagle-guard.service" \
    "$SDIR/config/eagle.conf"
do
    [ -f "$f" ] && ok "$(basename $f)" || { fail "EKSİK: $f"; MISS=$((MISS+1)); }
done
[ "$MISS" -gt 0 ] && { echo -e "\n${R}$MISS dosya eksik. ZIP'i tekrar açın.${N}"; exit 1; }

# Mevcut kurulum varsa temizle
step "MEVCUT KURULUM KONTROLÜ"
if [ -f /opt/eagle-guard/scripts/eagle-guard.sh ]; then
    warn "Mevcut kurulum tespit edildi — temizleniyor..."
    systemctl stop eagle-guard 2>/dev/null || true
    systemctl disable eagle-guard 2>/dev/null || true
    rm -f /var/run/eagle-guard.pid
    for chain in EG_L4 EG_L4_FWD EG_L7 EG_GAME; do
        iptables -D INPUT -j "$chain" 2>/dev/null || true
        iptables -F "$chain" 2>/dev/null || true
        iptables -X "$chain" 2>/dev/null || true
    done
    ip6tables -D INPUT -j EG_L4_6 2>/dev/null || true
    ip6tables -F EG_L4_6 2>/dev/null || true
    ip6tables -X EG_L4_6 2>/dev/null || true
    # Script ve web sil, config/data koru
    rm -f /opt/eagle-guard/scripts/eagle-guard.sh
    rm -rf /var/www/html/eagle-guard
    rm -f /etc/systemd/system/eagle-guard.service
    rm -f /usr/local/bin/eagle-guard
    ok "Eski kurulum temizlendi (config/data korundu)"
else
    ok "Mevcut kurulum yok — temiz kurulum"
fi

# Paketler
step "PAKET KURULUMU"
apt-get update -y >> "$LOG" 2>&1 && ok "apt update" || warn "apt update başarısız"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    iptables python3 curl wget iproute2 procps net-tools \
    apache2 php libapache2-mod-php php-json acl >> "$LOG" 2>&1 \
    && ok "Temel paketler" || warn "Bazı paketler kurulamadı"
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >> "$LOG" 2>&1 || true
DEBIAN_FRONTEND=noninteractive apt-get install -y ip6tables >> "$LOG" 2>&1 || true
DEBIAN_FRONTEND=noninteractive apt-get install -y mailutils  >> "$LOG" 2>&1 || true

# XDP/eBPF bağımlılıkları (v7.2) — eksikse XDP pas geçilir, iptables katmanı çalışır
step "XDP/eBPF BAĞIMLILIKLARI"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    clang llvm libbpf-dev libelf-dev gcc make pkg-config \
    linux-headers-$(uname -r) linux-tools-common \
    linux-tools-$(uname -r) bpftool >> "$LOG" 2>&1 \
    && ok "XDP bağımlılıkları kuruldu" || warn "XDP bağımlılıkları eksik — XDP katmanı devre dışı kalacak"

# DPDK (opt-in, ileride bind edilecek)
DEBIAN_FRONTEND=noninteractive apt-get install -y dpdk dpdk-dev >> "$LOG" 2>&1 \
    && ok "DPDK paketi kuruldu" || warn "DPDK paketi yok (opsiyonel, XDP yeterlidir)"

# Dizinler
step "DİZİNLER"
mkdir -p /opt/eagle-guard/{scripts,data,logs,config,tmp,xdp,dpdk}
ok "Oluşturuldu: /opt/eagle-guard/ (+ xdp/ dpdk/)"
mkdir -p /var/www/html/eagle-guard/api
ok "Oluşturuldu: /var/www/html/eagle-guard/"

# Dosyaları kopyala
step "DOSYALAR KOPYALANIYOR"
WEB=/var/www/html/eagle-guard
cp_f "$SDIR/scripts/eagle-guard.sh" "/opt/eagle-guard/scripts/eagle-guard.sh" "eagle-guard.sh"
chmod +x /opt/eagle-guard/scripts/eagle-guard.sh
ln -sf /opt/eagle-guard/scripts/eagle-guard.sh /usr/local/bin/eagle-guard
ok "Global komut: eagle-guard"
# XDP CLI wrapper
if [ -f "$SDIR/scripts/eagle-xdp" ]; then
    cp -f "$SDIR/scripts/eagle-xdp" /opt/eagle-guard/scripts/eagle-xdp
    chmod +x /opt/eagle-guard/scripts/eagle-xdp
    ln -sf /opt/eagle-guard/scripts/eagle-xdp /usr/local/bin/eagle-xdp
    ok "Global komut: eagle-xdp"
fi

cp_f "$SDIR/web/index.php"     "$WEB/index.php"     "web/index.php → $WEB"
cp_f "$SDIR/web/api/index.php" "$WEB/api/index.php" "web/api/index.php → $WEB/api"

# XDP dosyaları
if [ -d "$SDIR/xdp" ]; then
    cp -rf "$SDIR/xdp/"* /opt/eagle-guard/xdp/ 2>>"$LOG" && ok "xdp/ kopyalandı" || warn "xdp/ kopyalama hatası"
    chmod +x /opt/eagle-guard/xdp/*.sh 2>/dev/null || true
fi
# DPDK dosyaları
if [ -d "$SDIR/dpdk" ]; then
    cp -rf "$SDIR/dpdk/"* /opt/eagle-guard/dpdk/ 2>>"$LOG" && ok "dpdk/ kopyalandı" || warn "dpdk/ kopyalama hatası"
    chmod +x /opt/eagle-guard/dpdk/*.sh 2>/dev/null || true
fi

# uninstall ve fix — /opt/eagle-guard içine koy
[ -f "$SDIR/uninstall.sh" ] && {
    cp_f "$SDIR/uninstall.sh" "/opt/eagle-guard/uninstall.sh" "uninstall.sh"
    chmod +x /opt/eagle-guard/uninstall.sh
}
[ -f "$SDIR/fix.sh" ] && {
    cp_f "$SDIR/fix.sh" "/opt/eagle-guard/fix.sh" "fix.sh"
    chmod +x /opt/eagle-guard/fix.sh
}

# Config (varsa üzerine yazma)
if [ ! -f /opt/eagle-guard/config/eagle.conf ]; then
    cp_f "$SDIR/config/eagle.conf" "/opt/eagle-guard/config/eagle.conf" "eagle.conf"
else
    ok "eagle.conf korundu (üzerine yazılmadı)"
fi

# whitelist
if [ ! -f /opt/eagle-guard/config/whitelist.txt ]; then
    [ -f "$SDIR/config/whitelist.txt" ] \
        && cp_f "$SDIR/config/whitelist.txt" "/opt/eagle-guard/config/whitelist.txt" "whitelist.txt" \
        || { printf "127.0.0.1\n::1\n" > /opt/eagle-guard/config/whitelist.txt; ok "whitelist.txt oluşturuldu"; }
else
    ok "whitelist.txt korundu"
fi

# JSON veri dosyaları
[ ! -f /opt/eagle-guard/data/blocked.json ] && echo '{"blocked":[]}' > /opt/eagle-guard/data/blocked.json
[ ! -f /opt/eagle-guard/data/alerts.json  ] && echo '{"alerts":[]}'  > /opt/eagle-guard/data/alerts.json
[ ! -f /opt/eagle-guard/data/traffic.json ] && echo '{"points":[]}'  > /opt/eagle-guard/data/traffic.json
echo '{"status":"inactive","net":{"bps_in":0,"bps_out":0,"pps_in":0,"pps_out":0},"l4":{},"l7":{},"game":{},"sys":{"cpu":0,"mem":0,"conn":0,"uptime":0}}' \
    > /opt/eagle-guard/data/stats.json
ok "JSON veri dosyaları hazır"

cat > "$WEB/.htaccess" << 'HTA'
Options -Indexes
DirectoryIndex index.php
HTA
ok ".htaccess oluşturuldu"

# İzinler
step "İZİNLER"
chown -R www-data:www-data "$WEB" >> "$LOG" 2>&1 || true
chmod -R 755 "$WEB" >> "$LOG" 2>&1 || true
if command -v setfacl >/dev/null 2>&1; then
    setfacl -R -m u:www-data:rwx /opt/eagle-guard/data/   >> "$LOG" 2>&1 || true
    setfacl -R -m u:www-data:rx  /opt/eagle-guard/logs/   >> "$LOG" 2>&1 || true
    # v7.2: config'e www-data YAZMA yetkisi — UI'dan ayar kaydedebilsin
    setfacl -R -m u:www-data:rwx /opt/eagle-guard/config/ >> "$LOG" 2>&1 || true
    setfacl    -m u:www-data:rw  /opt/eagle-guard/config/eagle.conf >> "$LOG" 2>&1 || true
    ok "ACL izinleri ayarlandı (config: www-data RW)"
else
    chmod 777 /opt/eagle-guard/data/       >> "$LOG" 2>&1 || true
    chmod 666 /opt/eagle-guard/data/*.json >> "$LOG" 2>&1 || true
    # v7.2: config'e www-data yazma (ACL yoksa)
    chmod 775 /opt/eagle-guard/config/     >> "$LOG" 2>&1 || true
    chmod 664 /opt/eagle-guard/config/eagle.conf >> "$LOG" 2>&1 || true
    chown root:www-data /opt/eagle-guard/config/eagle.conf >> "$LOG" 2>&1 || true
    ok "chmod izinleri ayarlandı (config 664, www-data yazabilir)"
fi
chmod +x /opt/eagle-guard/scripts/eagle-guard.sh

# Sudoers
step "SUDO İZİNLERİ"
cat > /etc/sudoers.d/eagle-guard << 'SUDO'
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
ok "sudoers ayarlandı"
visudo -c -f /etc/sudoers.d/eagle-guard >> "$LOG" 2>&1 \
    && ok "sudoers syntax doğrulandı" || warn "sudoers syntax uyarısı"

# Apache
step "APACHE"
systemctl start apache2  >> "$LOG" 2>&1 || service apache2 start >> "$LOG" 2>&1 || true
systemctl enable apache2 >> "$LOG" 2>&1 || true
a2enmod rewrite >> "$LOG" 2>&1 || true
PHP_MOD=$(ls /etc/apache2/mods-available/php*.load 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.load//')
[ -n "$PHP_MOD" ] && { a2enmod "$PHP_MOD" >> "$LOG" 2>&1 || true; ok "PHP: $PHP_MOD"; }
for cf in /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf; do
    [ -f "$cf" ] && grep -q "AllowOverride None" "$cf" 2>/dev/null && \
        sed -i 's/AllowOverride None/AllowOverride All/g' "$cf" && ok "AllowOverride All: $(basename $cf)"
done
cat > /etc/apache2/conf-available/eagle-guard.conf << 'ACONF'
<Directory /var/www/html/eagle-guard>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    Require all granted
    DirectoryIndex index.php
</Directory>
ACONF
a2enconf eagle-guard >> "$LOG" 2>&1 || true
systemctl reload apache2 >> "$LOG" 2>&1 || systemctl restart apache2 >> "$LOG" 2>&1 || true
ok "Apache yapılandırıldı"

# Systemd
step "SYSTEMD SERVİSİ"
cp_f "$SDIR/systemd/eagle-guard.service" "/etc/systemd/system/eagle-guard.service" "eagle-guard.service"
systemctl daemon-reload  >> "$LOG" 2>&1 || true
systemctl enable eagle-guard >> "$LOG" 2>&1 || true
ok "Servis enable edildi (boot'ta otomatik başlar)"

# Logrotate
cat > /etc/logrotate.d/eagle-guard << 'LR'
/opt/eagle-guard/logs/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    create 644 root root
}
LR
ok "logrotate ayarlandı"

# XDP objesi build (best-effort, başarısız olursa iptables katmanı çalışır)
step "XDP BPF OBJESİ"
if [ -f /opt/eagle-guard/xdp/build.sh ]; then
    chmod +x /opt/eagle-guard/xdp/build.sh
    if bash /opt/eagle-guard/xdp/build.sh >> "$LOG" 2>&1; then
        ok "eagle_xdp.o üretildi"
    else
        warn "BPF build başarısız — XDP devre dışı, iptables katmanı aktif"
        warn "Sonra: cd /opt/eagle-guard/xdp && sudo bash build.sh"
    fi
fi

# WAF kurulumu (Nginx + ModSecurity)
step "WAF KURULUMU (Nginx + ModSecurity)"
# WAF dosyalarını kopyala
if [ -d "$SDIR/waf" ]; then
    mkdir -p /opt/eagle-guard/waf/{scripts,rules,templates,logs,data}
    cp -rf "$SDIR/waf/waf.conf"     /opt/eagle-guard/waf/waf.conf     2>>"$LOG" || true
    cp -rf "$SDIR/waf/nginx-waf.conf" /opt/eagle-guard/waf/nginx-waf.conf 2>>"$LOG" || true
    cp -rf "$SDIR/waf/rules/"*      /opt/eagle-guard/waf/rules/       2>>"$LOG" || true
    cp -rf "$SDIR/waf/templates/"*  /opt/eagle-guard/waf/templates/   2>>"$LOG" || true
    cp -rf "$SDIR/waf/scripts/"*    /opt/eagle-guard/waf/scripts/     2>>"$LOG" || true
    chmod +x /opt/eagle-guard/waf/scripts/*.sh 2>/dev/null || true
    # Placeholder include dosyaları (nginx hata vermesin)
    for f in geo-map.conf geo-enforce.conf ti-deny.conf uam-flag.conf; do
        [ ! -f "/opt/eagle-guard/waf/data/$f" ] && \
            echo "# empty — waf-ctl.sh rebuild ile üretilir" > "/opt/eagle-guard/waf/data/$f"
    done
    [ ! -f /opt/eagle-guard/waf/rules/eagle-custom.conf ] && \
        echo "# Eagle Guard özel kurallar — waf-ctl.sh rebuild ile üretilir" \
        > /opt/eagle-guard/waf/rules/eagle-custom.conf
    touch /opt/eagle-guard/waf/logs/audit.log \
          /opt/eagle-guard/waf/logs/block.log  \
          /opt/eagle-guard/waf/logs/access.log \
          /opt/eagle-guard/waf/logs/error.log 2>/dev/null || true
    chown -R www-data:www-data /opt/eagle-guard/waf/logs \
                                /opt/eagle-guard/waf/data \
                                /opt/eagle-guard/waf/rules 2>>"$LOG" || true
    ok "WAF dosyaları kopyalandı → /opt/eagle-guard/waf/"
    # waf-ctl sudoers kaydı
    echo "www-data ALL=(root) NOPASSWD: /opt/eagle-guard/waf/scripts/waf-ctl.sh" \
        >> /etc/sudoers.d/eagle-guard 2>/dev/null || true
    ok "WAF sudoers kaydı eklendi"
    # Nginx kuruluysa WAF'ı kur
    if command -v nginx >/dev/null 2>&1 || \
       DEBIAN_FRONTEND=noninteractive apt-get install -y nginx >> "$LOG" 2>&1; then
        info "Nginx WAF install-waf.sh ile kuruluyor..."
        if bash "$SDIR/waf/scripts/install-waf.sh" >> "$LOG" 2>&1; then
            ok "WAF (Nginx + ModSecurity) kuruldu ✓"
        else
            warn "WAF otomatik kurulumu başarısız — sonradan manuel kurun:"
            warn "  sudo bash /opt/eagle-guard/waf/scripts/install-waf.sh"
        fi
    else
        warn "Nginx kurulamadı — WAF sonradan kurulabilir:"
        warn "  sudo bash /opt/eagle-guard/waf/scripts/install-waf.sh"
    fi
else
    warn "WAF dizini bulunamadı ($SDIR/waf) — WAF atlandı"
fi

# Servis kurulumda BAŞLATILMIYOR — SSH güvenliği için manuel başlat
step "SERVİS HAZIR"
ok "Eagle Guard servisi enable edildi (boot'ta başlar)"
warn "Kurulum sırasında servis OTOMATİK BAŞLATILMIYOR"
warn "SSH bağlantınızı kaybetmemek için manuel başlatın:"
echo -e "\n  ${W}sudo systemctl start eagle-guard${N}\n"

# Doğrulama
step "DOĞRULAMA"
ck() { [ -f "$2" ] && ok "$1" || fail "$1 EKSİK: $2"; }
ck "eagle-guard.sh"    "/opt/eagle-guard/scripts/eagle-guard.sh"
ck "web/index.php"     "/var/www/html/eagle-guard/index.php"
ck "web/api/index.php" "/var/www/html/eagle-guard/api/index.php"
ck "systemd service"   "/etc/systemd/system/eagle-guard.service"
ck "sudoers"           "/etc/sudoers.d/eagle-guard"

HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost/eagle-guard/ 2>/dev/null || echo 000)
[ "$HTTP" = "200" ] && ok "HTTP 200 OK ✓" || warn "HTTP $HTTP — Apache log: tail -20 /var/log/apache2/error.log"

API=$(curl -s --connect-timeout 5 "http://localhost/eagle-guard/api/index.php?action=debug" 2>/dev/null || echo "")
echo "$API" | grep -q '"ok":true' && ok "API çalışıyor ✓" || warn "API yanıt vermiyor"

# Özet
IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "SUNUCU_IP")
echo ""
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${G}╔══════════════════════════════════════════════════════╗"
    echo -e "║  ✅  Eagle Guard v7.2 KURULUM BAŞARILI              ║"
    echo -e "║  Powered By Creart Cloud                            ║"
    echo -e "╚══════════════════════════════════════════════════════╝${N}"
else
    echo -e "${Y}╔══════════════════════════════════════════════════════╗"
    echo -e "║  ⚠  KURULUM TAMAMLANDI — ${ERRORS} SORUN VAR       ║"
    echo -e "║  Powered By Creart Cloud                            ║"
    echo -e "╚══════════════════════════════════════════════════════╝${N}"
fi
echo ""
echo -e "  ${G}🌐 Web Paneli:${N}   http://${IP}/eagle-guard/"
echo -e "  ${G}🔍 API Debug:${N}    http://${IP}/eagle-guard/api/index.php?action=debug"
echo -e "  ${G}🔒 WAF Proxy:${N}    http://${IP}:8080/  (Nginx + ModSecurity)"
echo ""
echo -e "  ${W}HIZLI BAŞLANGIÇ:${N}"
echo -e "  ${G}⏻ Başlat:${N}    sudo systemctl start eagle-guard"
echo -e "  ${Y}⚠  NOT:${N}      Servisi başlatmadan önce SSH bağlantınızı kontrol edin!"
echo -e "  ${G}⏸ Durdur:${N}    sudo systemctl stop eagle-guard"
echo -e "  ${G}📊 Durum:${N}    sudo eagle-guard status"
echo -e "  ${G}📋 Log:${N}      sudo eagle-guard logs"
echo -e "  ${G}🔎 L7:${N}       sudo eagle-guard rules-l7"
echo -e "  ${G}🔒 WAF:${N}      sudo eagle-guard waf-status"
echo -e "  ${G}❓ Yardım:${N}   sudo eagle-guard help"
echo ""
echo -e "  ${W}GELİŞMİŞ:${N}"
echo -e "  ${G}🦅 XDP aç:${N}   sudo sed -i 's/^XDP_ENABLED=no/XDP_ENABLED=yes/' /opt/eagle-guard/config/eagle.conf && sudo /opt/eagle-guard/xdp/eagle-xdp-loader.sh load"
echo -e "  ${G}🦅 XDP kapat:${N} sudo /opt/eagle-guard/xdp/eagle-xdp-loader.sh unload"
echo -e "  ${G}⚡ DPDK:${N}     sudo /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh check"
echo -e "  ${G}🌍 WAF kur:${N}  sudo bash /opt/eagle-guard/waf/scripts/install-waf.sh"
echo ""
echo -e "  ${Y}🔒 Güvenlik:${N}  SSH (22) ve HTTP/HTTPS (80/443) ASLA bloklanmaz"
echo -e "  ${G}🗑 Kaldır:${N}    sudo bash /opt/eagle-guard/uninstall.sh"
echo -e "  ${G}📄 Kurulum log:${N} $LOG"
echo ""
echo -e "  ${C}Powered By Creart Cloud${N}"
echo ""
