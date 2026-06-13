#!/bin/bash
# Eagle Guard v5.0 — Tam Kaldırma Scripti
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' W='\033[1;37m' N='\033[0m'
ok()   { echo -e "${G}  [OK]${N} $*"; }
info() { echo -e "${C}  [..]${N} $*"; }
step() { echo -e "\n${W}━━━ $* ━━━${N}"; }

[[ $(id -u) -ne 0 ]] && { echo -e "${R}Root gerekli: sudo bash uninstall.sh${N}"; exit 1; }

echo -e "\n${R}  ══════════════════════════════════════════${N}"
echo -e "${W}    Eagle Guard — Tam Kaldırma${N}"
echo -e "${R}  ══════════════════════════════════════════${N}\n"
echo -e "${Y}  UYARI: Eagle Guard tamamen silinecek ve sistem yeniden başlatılacak!${N}\n"
echo -n "  Onay için 'evet' yazın: "
read -r C
[[ "$C" != "evet" ]] && { echo -e "\n${C}  İptal edildi.${N}"; exit 0; }

step "SERVİS DURDURULUYOR"
systemctl stop eagle-guard    2>/dev/null && ok "Servis durduruldu"    || info "Servis zaten durmuştu"
systemctl disable eagle-guard 2>/dev/null && ok "Servis disable edildi" || true
rm -f /var/run/eagle-guard.pid
ok "PID dosyası temizlendi"

step "XDP DETACH"
if [ -x /opt/eagle-guard/xdp/eagle-xdp-loader.sh ]; then
    /opt/eagle-guard/xdp/eagle-xdp-loader.sh unload 2>/dev/null && ok "XDP detach edildi" || info "XDP yüklü değildi"
else
    for IF in $(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | cut -d@ -f1); do
        ip link set dev "$IF" xdp off 2>/dev/null || true
    done
fi
rm -rf /sys/fs/bpf/eagle 2>/dev/null || true
ok "BPF pin'leri temizlendi"

step "DPDK UNBIND (opsiyonel)"
if [ -x /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh ]; then
    /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh unbind 2>/dev/null || true
fi

step "IPTABLES TEMİZLENİYOR"
for chain in EG_GUARD EG_ACCEPT EG_L4 EG_L7 EG_GAME EG_SYNPROXY; do
    iptables -D INPUT   -j "$chain" 2>/dev/null || true
    iptables -D FORWARD -j "$chain" 2>/dev/null || true
    iptables -F "$chain" 2>/dev/null || true
    iptables -X "$chain" 2>/dev/null || true
done
iptables -t mangle -D PREROUTING -j EG_MANGLE 2>/dev/null || true
iptables -t mangle -F EG_MANGLE 2>/dev/null || true
iptables -t mangle -X EG_MANGLE 2>/dev/null || true
iptables -t raw -D PREROUTING -j EG_SYNPROXY_RAW 2>/dev/null || true
iptables -t raw -F EG_SYNPROXY_RAW 2>/dev/null || true
iptables -t raw -X EG_SYNPROXY_RAW 2>/dev/null || true
ip6tables -D INPUT  -j EG_GUARD6 2>/dev/null || true
ip6tables -F EG_GUARD6 2>/dev/null || true
ip6tables -X EG_GUARD6 2>/dev/null || true
ok "Tüm iptables zincirleri temizlendi (EG_GUARD + EG_L4 + EG_L7 + EG_GAME + mangle)"

step "KERNEL PARAMETRELERİ SIFIRLANIYOR"
sysctl -w net.ipv4.tcp_syncookies=1            >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.rp_filter=1        >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.log_martians=0     >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.accept_redirects=1 >/dev/null 2>&1 || true
ok "Kernel parametreleri varsayılana döndürüldü"

step "DOSYALAR SİLİNİYOR"

# /opt/eagle-guard — TAMAMEm sil
if [ -d /opt/eagle-guard ]; then
    rm -rf /opt/eagle-guard
    ok "Silindi: /opt/eagle-guard/"
else
    info "/opt/eagle-guard/ zaten yoktu"
fi

# Global komut
rm -f /usr/local/bin/eagle-guard
ok "Silindi: /usr/local/bin/eagle-guard"

# Web arayüzü
if [ -d /var/www/html/eagle-guard ]; then
    rm -rf /var/www/html/eagle-guard
    ok "Silindi: /var/www/html/eagle-guard/"
else
    info "/var/www/html/eagle-guard/ zaten yoktu"
fi

# Systemd service
rm -f /etc/systemd/system/eagle-guard.service
ok "Silindi: eagle-guard.service"
systemctl daemon-reload 2>/dev/null || true

# Sudoers
rm -f /etc/sudoers.d/eagle-guard
ok "Silindi: /etc/sudoers.d/eagle-guard"

# Apache conf
a2disconf eagle-guard 2>/dev/null || true
rm -f /etc/apache2/conf-available/eagle-guard.conf
rm -f /etc/apache2/conf-enabled/eagle-guard.conf
systemctl reload apache2 2>/dev/null || true
ok "Apache eagle-guard conf kaldırıldı"

# Logrotate
rm -f /etc/logrotate.d/eagle-guard
ok "Silindi: /etc/logrotate.d/eagle-guard"

# Geçici dosyalar
rm -f /tmp/eagle-install-*.log 2>/dev/null || true

echo ""
echo -e "${G}┌──────────────────────────────────────────────┐${N}"
echo -e "${G}│  ✅  Eagle Guard tamamen kaldırıldı          │${N}"
echo -e "${G}└──────────────────────────────────────────────┘${N}"
echo ""
echo -e "  ${Y}Sistem 5 saniye içinde yeniden başlatılıyor...${N}"
sleep 5
reboot
