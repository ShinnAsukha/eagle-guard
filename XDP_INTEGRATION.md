# Eagle Guard v7.1 — XDP/eBPF/DPDK Entegrasyonu

## Kısa özet
v7.1, mevcut iptables/nftables tabanlı L4/L7 korumanın **üstüne** eBPF/XDP
datapath ekler. XDP paketleri NIC driver seviyesinde (veya generic hook'ta)
işler — milyonlarca pps kapasitesi sağlar.

## 🔒 SSH & Web bağlantısı neden güvende?

eBPF programı (`xdp/eagle_xdp.c`) şu mantıkla çalışır:

1. **Whitelist** kontrolü → varsa **XDP_PASS**
2. **Hardban** kontrolü (özel, elle eklenir) → **XDP_DROP**
3. **Yönetim portu** kontrolü (TCP/22, 80, 443 + config'deki admin_ports) →
   **XDP_PASS** (KODDA SABİT — kaynak IP blacklist'te olsa bile!)
4. Config `enabled=0` ise sadece say, düşürme
5. Blacklist/rate-limit/SYN-flood kontrolleri

**Bu sıralama**, SSH/web trafiğinin XDP tarafından düşürülmesini
**matematiksel olarak imkansız** kılar. Yanlış yapılandırma, panik ban,
hatta saldırgan IP'si admin IP'sinde oturmuş olsa bile, TCP dport=22/80/443
ise paket geçer.

İstisna: `hardban` komutu kodun erken aşamasında tetiklenir ve yönetim
portlarını **bloklar**. Bu komutu yalnızca kasten kullanın.

## Hızlı başlangıç

```bash
# Kurulum (XDP bağımlılıkları otomatik yüklenir)
sudo bash install.sh

# XDP'yi aç
sudo nano /opt/eagle-guard/config/eagle.conf
#   XDP_ENABLED=yes
#   XDP_IFACE=auto        (default route NIC'i)
#   XDP_MODE=generic      (driver destekliyorsa 'native' dene)
#   XDP_SYN_LIMIT=200     (kaynak IP başına sn'de 200 SYN)
#   XDP_PPS_LIMIT=3000    (kaynak IP UDP/ICMP sn'de 3000 pps)

sudo eagle-xdp start
sudo eagle-xdp status

# Test: SSH oturumunu koparmadığını doğrula (başka bir terminalde)
ssh you@server "echo hâlâ oradayım"
```

## Kullanım

```bash
# Kara liste
sudo eagle-xdp ban 198.51.100.42
sudo eagle-xdp ban 203.0.113.0/24      # /24 prefix
sudo eagle-xdp list blacklist

# Beyaz liste
sudo eagle-xdp allow 10.0.0.0/8
sudo eagle-xdp whitelist-sync          # config/whitelist.txt → map

# İstatistik
sudo eagle-xdp status
# veya
sudo bpftool map dump pinned /sys/fs/bpf/eagle/stats
```

## Katman mimarisi

```
   ┌─────────────────────────────────────────────────┐
   │  Userland: eagle-guard (iptables yönetim)       │
   │           web panel (PHP)                       │
   ├─────────────────────────────────────────────────┤
   │  netfilter/iptables — L4/L7, connlimit, f2b     │  ← mevcut
   ├─────────────────────────────────────────────────┤
   │  XDP hook (kernel, driver veya generic)         │  ← YENİ v7.1
   │    ├─ whitelist  (PASS)                          │
   │    ├─ hardban    (DROP)                          │
   │    ├─ admin port (PASS — SABİT)                  │
   │    ├─ blacklist  (DROP)                          │
   │    └─ ratelimit  (DROP)                          │
   ├─────────────────────────────────────────────────┤
   │  NIC                                             │
   └─────────────────────────────────────────────────┘
```

XDP erken drop → CPU yükü düşer → iptables katmanına ulaşan paket azalır
→ sistem saldırı altında bile SSH cevap verebilir.

## DPDK?

Opsiyonel. `dpdk/README.md` bakın. Tek NIC'li sunucularda **gereksiz**;
XDP yeterli.

## Geri alma

```bash
sudo eagle-xdp stop            # sadece XDP detach
sudo systemctl stop eagle-guard
sudo bash /opt/eagle-guard/uninstall.sh
```
