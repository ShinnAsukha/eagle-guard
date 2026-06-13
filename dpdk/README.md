# Eagle Guard — DPDK Entegrasyonu

## Nedir?
DPDK (Data Plane Development Kit), bir NIC'i **kernel'den tamamen koparıp**
user-space'ten direkt kontrol etmenizi sağlar. Milyonlarca pps paket
işleyebilir ama:

- O NIC üzerinden **SSH/web veremezsiniz** (kernel artık göremez).
- Yanlış NIC'e bind ederseniz **erişiminizi kaybedersiniz**.

## Bu yüzden Eagle Guard v7.1 DPDK entegrasyonu şöyle:

1. Varsayılan: **kapalı** (`DPDK_ENABLED=no`)
2. Yönetim NIC'i (default route) **otomatik algılanır** ve **asla**
   DPDK'ya verilmez.
3. `DPDK_IFACE` = yönetim NIC ise bind reddedilir.
4. Interaktif onay istenir.

## Önerilen topoloji

```
  ┌─────────┐  eth0 ─── Yönetim + SSH + Web       (kernel, XDP, iptables)
  │ Sunucu  │
  └─────────┘  eth1 ─── DDoS geleceği trafik      (DPDK)
```

Saldırı trafiği DPDK NIC'ine DNAT/yönlendirme ile gelir; filtrelenip
temizlenen trafik gerekirse veth/bridge ile kernel stack'ine döner.

## Kullanım

```bash
# 1. Config
sudo nano /opt/eagle-guard/config/eagle.conf
# DPDK_ENABLED=yes
# DPDK_IFACE=eth1
# DPDK_DRIVER=vfio-pci
# DPDK_HUGEPAGES=512

# 2. Kontrol
sudo /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh check

# 3. Bind
sudo /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh bind

# 4. Durum
sudo /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh status

# Geri al
sudo /opt/eagle-guard/dpdk/eagle-dpdk-setup.sh unbind
```

## Alternatif: DPDK kullanmayın, XDP yeterli

Tek NIC'li sunucularda **DPDK kullanmayın**. XDP (eBPF) zaten 10+ Mpps
işleyebilir ve SSH/web'e dokunmaz. `XDP_ENABLED=yes` yeterli.

## Uyarı: AF_XDP = orta yol

`AF_XDP` socket (XDP + zero-copy) DPDK hızına yaklaşır ama kernel'i
kapatmaz. Eagle Guard v7.2'de değerlendirilecek.
