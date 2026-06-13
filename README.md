# 🦅 Eagle Guard v7.3 — Enterprise DDoS Protection + WAF

Kurumsal seviye DDoS koruması ve Web Application Firewall sistemi.

## ✨ Özellikler

### 🛡️ Layer 4 (Network)
- SYN Flood koruması (SYNPROXY)
- UDP Flood detection
- ICMP Flood limiting
- Port scan detection
- RapidReset (HTTP/2 SETTINGS) koruması
- TCP flag anomaly detection
- Bogon IP filtering

### 🔐 Layer 7 (Application)
- HTTP/HTTPS flood koruması
- SSH brute force detection
- Rate limiting (endpoint bazı)
- Connection limiting
- Method-based filtering
- User-Agent validation

### 🌐 WAF (Web Application Firewall)
- **ModSecurity v3** + **OWASP CRS**
- SQL Injection tespiti
- XSS koruması
- RFI/LFI koruması
- Path Traversal bloğu
- Bot Detection
- GeoIP Blocking

## 🚀 Kurulum

```bash
git clone https://github.com/USERNAME/eagle-guard.git
cd eagle-guard/EagleGuard_v7.3

sudo bash install.sh
sudo bash waf/scripts/install-waf.sh
```

## 🌐 Erişim

- Dashboard: `http://SUNUCU_IP/eagle-guard/`
- WAF Proxy: `http://SUNUCU_IP:8080/`

## 🧪 WAF Test

```bash
# Normal (geçer)
curl -I http://localhost:8080/

# SQL Injection (bloke)
curl 'http://localhost:8080/?id=1%27 OR 1=1--'

# XSS (bloke)
curl 'http://localhost:8080/?s=<script>alert(1)</script>'

# Bot (bloke)
curl -A 'nikto/1.0' http://localhost:8080/

# Path Traversal (bloke)
curl 'http://localhost:8080/../../etc/passwd'
```

## 🔧 Konfigürasyon

`/opt/eagle-guard/config/eagle.conf`:
- Layer 4/7 rate limits
- Anomaly detection thresholds
- Game port lists
- Notifications

`/opt/eagle-guard/waf/waf.conf`:
- WAF paranoia level
- GeoIP settings
- Bot detection patterns

## 📊 Dashboard

- Real-time attack metrics
- Layer 4/7 statistics
- WAF audit logs
- IP whitelist/blacklist
- Service control
- Traffic graphs

## 🌟 Teknoloji Stack

- **iptables** — Layer 4 filtering
- **Nginx** — Reverse proxy + WAF
- **ModSecurity** — WAF engine
- **OWASP CRS** — Detection rules
- **Fail2ban** — Log-based blocking
- **PHP** — Dashboard backend
- **Chart.js** — Visualization

## 📝 License

Creeart Cloud — Enterprise Edition

## 🤝 Support

Issues: https://github.com/USERNAME/eagle-guard/issues

---

**Version**: 7.3 (Optimized)
**Last Update**: April 2026
**Status**: Production Ready ✅
