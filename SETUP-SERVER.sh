#!/bin/bash
################################################################################
#  🦅 EAGLE GUARD v7.3 — SERVER SETUP FIX
#  Sunucuda çalıştır: sudo bash SETUP-SERVER.sh
################################################################################

set -e

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' N='\033[0m'

log_info()  { echo -e "${C}▶${N} $1"; }
log_ok()    { echo -e "${G}✓${N} $1"; }
log_warn()  { echo -e "${Y}⚠${N} $1"; }
log_err()   { echo -e "${R}✗${N} $1"; }

clear
echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${C}  🦅 EAGLE GUARD v7.3 SERVER SETUP${N}"
echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""

# Root check
[ "$(id -u)" != "0" ] && { log_err "Root gerekli: sudo bash SETUP-SERVER.sh"; exit 1; }

# ═══════════════════════════════════════════════════════════════════════════
# 1) DNS FIX
# ═══════════════════════════════════════════════════════════════════════════

log_info "1/8: DNS ayarlanıyor..."

# systemd-resolved'u kapat
sudo systemctl stop systemd-resolved 2>/dev/null || true
sudo systemctl disable systemd-resolved 2>/dev/null || true

# /etc/resolv.conf'ı oluştur
sudo bash -c 'cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
options timeout:2 attempts:3 rotate single-request-reopen
EOF'

log_ok "DNS ayarlandı"

# ═══════════════════════════════════════════════════════════════════════════
# 2) HOSTNAME FIX
# ═══════════════════════════════════════════════════════════════════════════

log_info "2/8: Hostname ayarlanıyor..."

HOSTNAME=$(hostname)
IP_ADDR=$(hostname -I | awk '{print $1}')

if ! grep -q "^$IP_ADDR" /etc/hosts; then
    echo "$IP_ADDR $HOSTNAME" | sudo tee -a /etc/hosts > /dev/null
fi

log_ok "Hostname: $HOSTNAME ($IP_ADDR)"

# ═══════════════════════════════════════════════════════════════════════════
# 3) FIREWALL DNS RULES
# ═══════════════════════════════════════════════════════════════════════════

log_info "3/8: Firewall kuralları ayarlanıyor..."

sudo iptables -I OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
sudo iptables -I OUTPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true

if command -v iptables-save &>/dev/null; then
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null 2>&1 || true
fi

log_ok "Firewall kuralları eklendi"

# ═══════════════════════════════════════════════════════════════════════════
# 4) KILL CONFLICTING SERVICES
# ═══════════════════════════════════════════════════════════════════════════

log_info "4/8: Çakışan servisler durduruluyor..."

sudo killall -9 apache2 httpd nginx 2>/dev/null || true
sleep 2

log_ok "Servisler temizlendi"

# ═══════════════════════════════════════════════════════════════════════════
# 5) PERMISSIONS FIX
# ═══════════════════════════════════════════════════════════════════════════

log_info "5/8: İzinler ayarlanıyor..."

if [ -d /var/www/html/eagle-guard ]; then
    sudo chown -R www-data:www-data /var/www/html/eagle-guard
    sudo chmod -R 755 /var/www/html/eagle-guard
    sudo chmod 644 /var/www/html/eagle-guard/index.php 2>/dev/null || true
    sudo chmod 644 /var/www/html/eagle-guard/api/index.php 2>/dev/null || true
fi

if [ -d /opt/eagle-guard ]; then
    sudo chown -R root:root /opt/eagle-guard/scripts
    sudo chmod 755 /opt/eagle-guard/scripts/*.sh 2>/dev/null || true
    sudo chown -R www-data:www-data /opt/eagle-guard/data /opt/eagle-guard/logs
    sudo chmod 755 /opt/eagle-guard/data /opt/eagle-guard/logs
fi

log_ok "İzinler ayarlandı"

# ═══════════════════════════════════════════════════════════════════════════
# 6) APACHE SETUP
# ═══════════════════════════════════════════════════════════════════════════

log_info "6/8: Apache yapılandırılıyor..."

# Port config
sudo bash -c 'cat > /etc/apache2/ports.conf << PORTS
Listen 80
PORTS'

# Apache modules
sudo a2enmod rewrite 2>/dev/null || true
sudo a2enmod php8.1 2>/dev/null || a2enmod php 2>/dev/null || true

# Apache config
sudo bash -c 'cat > /etc/apache2/sites-available/000-default.conf << APACHECONF
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html/eagle-guard>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php
    </Directory>

    <FilesMatch "\.php$">
        SetHandler application/x-httpd-php
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
APACHECONF'

sudo systemctl enable apache2 2>/dev/null || true
sudo systemctl start apache2

sleep 2

if sudo systemctl is-active --quiet apache2; then
    log_ok "Apache başlatıldı (port 80)"
else
    log_warn "Apache başlanamadı"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 7) NGINX WAF SETUP
# ═══════════════════════════════════════════════════════════════════════════

log_info "7/8: Nginx WAF yapılandırılıyor..."

sudo bash -c 'cat > /etc/nginx/conf.d/eagle-waf.conf << NGINX
server {
    listen 8080;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX'

sudo systemctl enable nginx 2>/dev/null || true
sudo systemctl restart nginx

sleep 2

if sudo systemctl is-active --quiet nginx; then
    log_ok "Nginx başlatıldı (port 8080 WAF)"
else
    log_warn "Nginx başlanamadı"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 8) EAGLE GUARD CONFIG & START
# ═══════════════════════════════════════════════════════════════════════════

log_info "8/8: Eagle Guard hazırlanıyor..."

# Mevcut servisi durdur
sudo systemctl stop eagle-guard 2>/dev/null || true

# Config'i kopa (varsa, kaydet)
if [ ! -f /opt/eagle-guard/config/eagle.conf.bak ]; then
    [ -f /opt/eagle-guard/config/eagle.conf ] && \
        sudo cp /opt/eagle-guard/config/eagle.conf /opt/eagle-guard/config/eagle.conf.bak
fi

# Optimized config'i kopyala (eğer ZIP'ten geliyorsa)
if [ -f config/eagle.conf ]; then
    sudo cp config/eagle.conf /opt/eagle-guard/config/eagle.conf
fi

# Servis basla
sudo systemctl daemon-reload
sudo systemctl enable eagle-guard 2>/dev/null || true

# SSH'yi whitelist'e ekle (kesilmemek için)
if [ -f /opt/eagle-guard/config/whitelist.txt ]; then
    sudo bash -c 'echo "22" >> /opt/eagle-guard/config/whitelist.txt 2>/dev/null || true'
fi

log_ok "Eagle Guard yapılandırıldı"

# ═══════════════════════════════════════════════════════════════════════════
# TESTS
# ═══════════════════════════════════════════════════════════════════════════

echo ""
log_info "═══════════════════════════════════════════════════════"
log_ok "SETUP TAMAMLANDI"
log_info "═══════════════════════════════════════════════════════"
echo ""

log_info "Dashboard:  http://${IP_ADDR}/eagle-guard/"
log_info "WAF Proxy:  http://${IP_ADDR}:8080/"
echo ""

log_info "Test komutları:"
echo "  Normal:     curl -I http://localhost:8080/"
echo "  SQL Inject: curl 'http://localhost:8080/?id=1%27 OR 1=1--'"
echo "  XSS:        curl 'http://localhost:8080/?s=<script>alert(1)</script>'"
echo ""

log_info "Eagle Guard'ı başlatmak için:"
echo "  sudo systemctl start eagle-guard"
echo ""

log_info "Logları görmek için:"
echo "  tail -f /opt/eagle-guard/logs/eagle.log"
echo "  tail -f /opt/eagle-guard/waf/logs/audit.log"
echo ""

log_ok "Hazır! Dashboard'a erişebilirsin."
echo ""
