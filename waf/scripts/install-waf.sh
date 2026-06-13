#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════
#  Eagle Guard WAF kurulum scripti (v7.4)
#  Nginx + libmodsecurity3 + ModSecurity-nginx + OWASP CRS
# ═════════════════════════════════════════════════════════════════
set -e

EG=/opt/eagle-guard
WAF="$EG/waf"
CRS_VER="v4.3.0"
LOG="/var/log/eagle-waf-install.log"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

[[ $EUID -ne 0 ]] && { echo "Root gerekli"; exit 1; }

echo "══════════════════════════════════════════════════════"
echo "  🦅 Eagle Guard WAF Kurulum"
echo "══════════════════════════════════════════════════════"

command -v apt-get >/dev/null 2>&1 || { echo "Bu script Debian/Ubuntu içindir"; exit 1; }

# 1) Paketleri kur
echo "▶ Paketler yükleniyor..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
    nginx libnginx-mod-http-modsecurity \
    libmaxminddb0 libmaxminddb-dev mmdb-bin \
    curl wget git unzip ca-certificates \
    || { echo "⚠ ModSec nginx modülü eksik — kaynaktan derleme gerek (rehber log'da)"; }

# nginx-module-geoip2 (Ubuntu paket yoksa atla)
apt-get install -y libnginx-mod-http-geoip2 2>/dev/null || echo "  (geoip2 modülü yok — yine de çalışır, geoip kapalı)"

# 2) ModSecurity temel config
echo "▶ ModSecurity yapılandırılıyor..."
mkdir -p /etc/nginx/modsec
if [[ ! -f /etc/nginx/modsec/modsecurity.conf ]]; then
    curl -fsSL https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/modsecurity.conf-recommended \
        -o /etc/nginx/modsec/modsecurity.conf || true
    [[ -f /etc/nginx/modsec/modsecurity.conf ]] && \
        sed -i 's/^SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf
fi
[[ ! -f /etc/nginx/modsec/unicode.mapping ]] && \
    curl -fsSL https://raw.githubusercontent.com/SpiderLabs/ModSecurity/v3/master/unicode.mapping \
        -o /etc/nginx/modsec/unicode.mapping || true

# 3) OWASP CRS
echo "▶ OWASP Core Rule Set ($CRS_VER) yükleniyor..."
if [[ ! -d /etc/nginx/modsec/crs ]]; then
    cd /etc/nginx/modsec
    git clone --depth=1 --branch "$CRS_VER" https://github.com/coreruleset/coreruleset.git crs 2>/dev/null || \
        git clone --depth=1 https://github.com/coreruleset/coreruleset.git crs
    cp crs/crs-setup.conf.example crs/crs-setup.conf
fi

# 4) Ana ModSec include config
cat > /etc/nginx/modsec/main.conf << 'MSC'
# Eagle Guard WAF — ModSecurity master config
Include /etc/nginx/modsec/modsecurity.conf
Include /etc/nginx/modsec/crs/crs-setup.conf
Include /etc/nginx/modsec/crs/rules/*.conf
# Eagle custom rules (JSON'dan üretilir)
Include /opt/eagle-guard/waf/rules/eagle-custom.conf
MSC

# 5) Eagle custom rules placeholder
[[ ! -f "$WAF/rules/eagle-custom.conf" ]] && cat > "$WAF/rules/eagle-custom.conf" << 'ECR'
# Eagle Guard özel kuralları — UI'dan yönetilir
# Bu dosya waf-ctl.sh rebuild ile custom.json'dan üretilir
ECR

# 6) Nginx WAF server config
cp "$WAF/nginx-waf.conf" /etc/nginx/conf.d/eagle-waf.conf
# upstream değişkeni — config'ten oku
UPSTREAM=$(grep '^WAF_UPSTREAM=' "$WAF/waf.conf" | cut -d= -f2- | tr -d ' "')
UPSTREAM="${UPSTREAM:-http://127.0.0.1:80}"
sed -i "1i map \$host \$eg_upstream { default \"$UPSTREAM\"; }" /etc/nginx/conf.d/eagle-waf.conf

# 7) GeoIP DB
echo "▶ GeoIP veritabanı..."
mkdir -p "$WAF/data"
if [[ ! -f "$WAF/data/GeoLite2-Country.mmdb" ]]; then
    # Kamuya açık ücretsiz CDN'den (MaxMind artık key istiyor)
    curl -fsSL -o "$WAF/data/GeoLite2-Country.mmdb" \
        https://raw.githubusercontent.com/P3TERX/GeoLite.mmdb/download/GeoLite2-Country.mmdb \
        || echo "  (GeoIP DB indirilemedi — geoip sonra manuel yüklenebilir)"
fi

# 8) Initial placeholder include dosyaları (nginx include hata vermesin)
for f in geo-map.conf geo-enforce.conf ti-deny.conf uam-flag.conf; do
    [[ ! -f "$WAF/data/$f" ]] && echo "# empty — waf-ctl üretir" > "$WAF/data/$f"
done

# 9) Log dizini + izin
mkdir -p "$WAF/logs"
touch "$WAF/logs/audit.log" "$WAF/logs/block.log"
chown -R www-data:www-data "$WAF/logs" "$WAF/data" "$WAF/rules"
chmod 664 "$WAF/logs"/*.log "$WAF/data"/*.conf "$WAF/rules"/*.json 2>/dev/null || true

# 10) İlk rebuild (TI/GeoIP/Custom rules)
bash "$WAF/scripts/waf-ctl.sh" rebuild || true

# 11) Nginx test + reload
echo "▶ Nginx config testi..."
nginx -t && systemctl reload nginx && echo "✓ Nginx WAF aktif (port 8080)" || {
    echo "✗ Nginx config hatası — audit log'a bakın: tail /var/log/nginx/error.log"
    exit 2
}

# 12) Systemd timer — TI feed otomatik güncelleme
cat > /etc/systemd/system/eagle-waf-ti.service << 'SVC'
[Unit]
Description=Eagle Guard WAF — Threat Intel feed sync
[Service]
Type=oneshot
ExecStart=/opt/eagle-guard/waf/scripts/waf-ctl.sh ti-sync
SVC
cat > /etc/systemd/system/eagle-waf-ti.timer << 'TMR'
[Unit]
Description=Eagle WAF TI sync — 6 saatte bir
[Timer]
OnBootSec=5min
OnUnitActiveSec=6h
Persistent=true
[Install]
WantedBy=timers.target
TMR
systemctl daemon-reload
systemctl enable --now eagle-waf-ti.timer 2>/dev/null || true

echo
echo "══════════════════════════════════════════════════════"
echo "  ✓ WAF kurulumu tamamlandı"
echo "══════════════════════════════════════════════════════"
echo "  Nginx WAF listen: 8080 (reverse proxy → $UPSTREAM)"
echo "  OWASP CRS:        /etc/nginx/modsec/crs/"
echo "  Custom rules:     $WAF/rules/"
echo "  Audit log:        $WAF/logs/audit.log"
echo "  Web panel → WAF sekmesi ile yönetebilirsiniz"
echo
echo "  🧪 Test:"
echo "    curl -I http://localhost:8080/"
echo "    curl 'http://localhost:8080/?id=1%27%20OR%201=1--'   # SQLi blok"
