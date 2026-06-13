# 🦅 Eagle Guard v7.3 — Kurulum Rehberi (Türkçe)

## 📋 Gereksinimler

- Ubuntu 22.04 LTS (veya 20.04)
- Root erişim
- 2GB RAM minimum
- Internet bağlantısı

## 🚀 Adım Adım Kurulum

### Adım 1: SSH Bağlantısı

```bash
ssh root@SUNUCU_IP
```

### Adım 2: Repository Klonla

```bash
cd /tmp
git clone https://github.com/USERNAME/eagle-guard.git
cd eagle-guard/EagleGuard_v7.3
```

Veya ZIP'ten:

```bash
cd /tmp
unzip EagleGuard_v7.3.zip
cd EagleGuard_v7.3
```

### Adım 3: Eagle Guard Kur (5 dakika)

```bash
sudo bash install.sh
```

Kontrol et:
```bash
sudo systemctl status eagle-guard
```

### Adım 4: WAF Kur (3-5 dakika)

```bash
sudo bash waf/scripts/install-waf.sh
```

Kontrol et:
```bash
sudo systemctl status nginx
```

### Adım 5: DNS Ayarla (Önemli!)

```bash
sudo bash -c 'cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF'
```

### Adım 6: Firewall Kuralları (Önemli!)

```bash
sudo iptables -I OUTPUT -p udp --dport 53 -j ACCEPT
sudo iptables -I OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null 2>&1 || true
```

---

## 🧪 WAF Test Komutları

**Normal İstek (200 OK geçmeli):**
```bash
curl -I http://localhost:8080/
```

**SQL Injection (403 Forbidden bloke olmalı):**
```bash
curl 'http://localhost:8080/?id=1%27 OR 1=1--'
```

**XSS (403 Forbidden bloke olmalı):**
```bash
curl 'http://localhost:8080/?s=<script>alert(1)</script>'
```

**Bot Detection (403 Forbidden bloke olmalı):**
```bash
curl -A 'nikto/1.0' http://localhost:8080/
```

**Path Traversal (403 Forbidden bloke olmalı):**
```bash
curl 'http://localhost:8080/../../etc/passwd'
```

✅ **Eğer 4 testte de beklenen sonuç alırsan, sistem hazır!**

---

## 📊 Dashboard Erişim

```
http://SUNUCU_IP/eagle-guard/
```

Varsayılan kullanıcı: `admin`
Varsayılan şifre: `admin123` (DEĞİŞTİR!)

---

## 🔍 Günlükleri Kontrol Et

**Eagle Guard:**
```bash
tail -f /opt/eagle-guard/logs/eagle.log
```

**WAF Audit:**
```bash
tail -f /opt/eagle-guard/waf/logs/audit.log
```

**Nginx Hatası:**
```bash
tail -f /var/log/nginx/error.log
```

---

## ⚙️ Yönetim Komutları

**Servis Kontrol:**
```bash
sudo systemctl status eagle-guard
sudo systemctl status nginx
sudo systemctl restart eagle-guard
sudo systemctl restart nginx
```

**CLI Komutları:**
```bash
sudo eagle-guard status
sudo eagle-guard block 1.2.3.4
sudo eagle-guard unblock 1.2.3.4
sudo eagle-guard help
```

**Firewall Kuralları Gör:**
```bash
sudo iptables -L EG_L4 -nvx
sudo iptables -L EG_L7 -nvx
```

---

## 🛠️ Konfigürasyon

### Eagle Guard Config

`/opt/eagle-guard/config/eagle.conf`:
- `INTERVAL` — Kontrol sıklığı (saniye)
- `L4_SYN_RATE` — SYN flood limit
- `L7_HTTP_RATE` — HTTP rate limit
- `ANOMALY_ENABLED` — Anomali tespiti
- `AUTO_BLOCK` — Otomatik IP engelle

### WAF Config

`/opt/eagle-guard/waf/waf.conf`:
- `WAF_PARANOIA` — Paranoia seviyesi (1-4)
- `WAF_MODE` — block / log (sadece kayıt yap)
- `GEO_ENABLED` — GeoIP engelleme

---

## 🆘 Sorun Giderme

### Eagle Guard başlamıyor

```bash
sudo journalctl -u eagle-guard -n 50 --no-pager
```

### Nginx başlamıyor

```bash
sudo nginx -t
sudo systemctl restart nginx
```

### WAF kurulamıyor

```bash
sudo bash waf/scripts/install-waf.sh 2>&1 | tail -30
```

### DNS çalışmıyor

```bash
nslookup google.com 8.8.8.8
```

---

## 📞 Destek

GitHub Issues: https://github.com/USERNAME/eagle-guard/issues

---

**Kurulum Tamamlandı! 🎉**

Dashboard'a gir ve saldırıları izle.
