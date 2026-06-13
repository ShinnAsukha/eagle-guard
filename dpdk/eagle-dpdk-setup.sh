#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║   Eagle Guard — DPDK Kurulum Yardımcısı (v7.1)                      ║
# ║                                                                      ║
# ║   ⚠ DİKKAT: DPDK bir NIC'i kernel'den koparır. O NIC üzerinden       ║
# ║   SSH/web verirseniz erişiminizi kaybedersiniz!                      ║
# ║                                                                      ║
# ║   Bu script YALNIZCA ayrı bir NIC üzerinde DPDK çalıştırır ve        ║
# ║   yönetim NIC'i (default route) üzerinde İŞLEM YAPMAZ.               ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -u

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' N='\033[0m'
ok()   { echo -e "${G}  [OK]${N} $*"; }
info() { echo -e "${C}  [..]${N} $*"; }
warn() { echo -e "${Y}  [!!]${N} $*"; }
fail() { echo -e "${R}  [XX]${N} $*"; }

EG_ROOT="/opt/eagle-guard"
CONF="${EG_ROOT}/config/eagle.conf"
[ -f "$CONF" ] && . "$CONF" || true

DPDK_ENABLED="${DPDK_ENABLED:-no}"
DPDK_IFACE="${DPDK_IFACE:-}"      # mutlaka explicit: eth1, enp2s0 vb.
DPDK_DRIVER="${DPDK_DRIVER:-vfio-pci}"  # vfio-pci veya uio_pci_generic
DPDK_HUGEPAGES="${DPDK_HUGEPAGES:-512}"  # 2MB page sayısı

[ "$(id -u)" != "0" ] && { fail "root gerekli"; exit 1; }

MGMT_IF=$(ip -o route show default 2>/dev/null | awk '{print $5; exit}')

cmd_check() {
    info "DPDK ortam kontrolü..."
    command -v dpdk-devbind.py >/dev/null 2>&1 && ok "dpdk-devbind.py bulundu" \
        || { fail "DPDK yüklü değil — apt install dpdk"; return 1; }
    [ -d /sys/kernel/mm/hugepages ] && ok "hugepages desteği var" \
        || { fail "Kernel hugepage desteği yok"; return 2; }
    lsmod | grep -q vfio_pci && ok "vfio-pci yüklü" \
        || warn "vfio-pci yüklü değil — modprobe vfio-pci"
    ok "Yönetim interface: $MGMT_IF (DPDK ASLA buna dokunmayacak)"
}

cmd_guardrail() {
    # Kullanıcının yanlışlıkla mgmt NIC'ini binding yapmasını engelle
    if [ -z "$DPDK_IFACE" ]; then
        fail "DPDK_IFACE tanımlanmamış. $CONF içinde ayarlayın."
        fail "ÖRNEK: DPDK_IFACE=eth1   (ASLA $MGMT_IF yazmayın!)"
        return 10
    fi
    if [ "$DPDK_IFACE" = "$MGMT_IF" ]; then
        fail "⛔ DPDK_IFACE ($DPDK_IFACE) = yönetim NIC'i ($MGMT_IF)"
        fail "⛔ Bu SSH erişiminizi kesecek. İptal edildi."
        return 11
    fi
    ip link show "$DPDK_IFACE" >/dev/null 2>&1 \
        || { fail "Interface yok: $DPDK_IFACE"; return 12; }
    # IP atanmışsa uyar
    if ip -4 addr show dev "$DPDK_IFACE" | grep -q 'inet '; then
        warn "$DPDK_IFACE üzerinde IP tanımlı — DPDK bağlanırsa o IP kaybolur!"
        warn "Eğer bu NIC üzerinden yönetim yapıyorsanız, ABORT edin."
        # interactive onay varsa sor
        if [ -t 0 ] && [ "${EG_DPDK_FORCE:-}" != "1" ]; then
            read -r -p "  Yine de devam? (evet yazın): " a
            [ "$a" = "evet" ] || { info "İptal"; return 13; }
        fi
    fi
    ok "Guardrail geçti: $DPDK_IFACE ≠ $MGMT_IF"
}

cmd_hugepages() {
    info "Hugepage'ler ayarlanıyor: $DPDK_HUGEPAGES x 2MB"
    echo "$DPDK_HUGEPAGES" > /proc/sys/vm/nr_hugepages
    mkdir -p /mnt/huge
    mountpoint -q /mnt/huge || mount -t hugetlbfs nodev /mnt/huge
    # kalıcı
    grep -q "/mnt/huge" /etc/fstab 2>/dev/null || \
        echo "nodev /mnt/huge hugetlbfs defaults 0 0" >> /etc/fstab
    ok "Hugepages: $(cat /proc/sys/vm/nr_hugepages)"
}

cmd_bind() {
    cmd_guardrail || return $?
    cmd_hugepages
    # Modül yükle
    case "$DPDK_DRIVER" in
        vfio-pci)
            modprobe vfio-pci || { fail "vfio-pci yüklenemedi"; return 20; }
            ;;
        uio_pci_generic)
            modprobe uio_pci_generic || { fail "uio_pci_generic yüklenemedi"; return 20; }
            ;;
        *) fail "Bilinmeyen driver: $DPDK_DRIVER"; return 21 ;;
    esac

    # Önce interface'i down al
    ip link set dev "$DPDK_IFACE" down 2>/dev/null || true

    # PCI adresini bul
    local PCI
    PCI=$(ethtool -i "$DPDK_IFACE" 2>/dev/null | awk '/bus-info/ {print $2}')
    [ -z "$PCI" ] && { fail "$DPDK_IFACE için PCI adresi alınamadı"; return 22; }

    info "DPDK binding: $DPDK_IFACE ($PCI) → $DPDK_DRIVER"
    dpdk-devbind.py --bind="$DPDK_DRIVER" "$PCI" \
        && ok "Binding başarılı" \
        || { fail "Binding başarısız"; return 23; }

    # Durum raporu
    dpdk-devbind.py --status-dev net | sed 's/^/  /'
    ok "DPDK hazır. Uygulama: dpdk-testpmd veya pkt-gen kullanılabilir."
}

cmd_unbind() {
    [ -z "$DPDK_IFACE" ] && { fail "DPDK_IFACE tanımsız"; return 1; }
    local PCI
    PCI=$(dpdk-devbind.py --status-dev net | grep -i "$DPDK_IFACE\|$DPDK_IFACE" | awk '{print $1}' | head -1)
    # Binding'teyken orijinal driver otomatik dönmüyor — yaygın driver'ları dene
    for drv in e1000 e1000e igb ixgbe i40e ice mlx5_core r8169 virtio-pci; do
        if [ -n "$PCI" ]; then
            dpdk-devbind.py --bind="$drv" "$PCI" 2>/dev/null && { ok "$DPDK_IFACE → $drv"; break; }
        fi
    done
    ip link set dev "$DPDK_IFACE" up 2>/dev/null || true
    ok "DPDK unbind denendi"
}

cmd_status() {
    command -v dpdk-devbind.py >/dev/null || { warn "DPDK yüklü değil"; return 0; }
    echo "=== DPDK Network Devices ==="
    dpdk-devbind.py --status-dev net | sed 's/^/  /'
    echo ""
    echo "=== Hugepages ==="
    grep Huge /proc/meminfo | sed 's/^/  /'
    echo "=== Guardrail ==="
    echo "  Yönetim NIC: $MGMT_IF (korunuyor)"
    echo "  DPDK NIC:    ${DPDK_IFACE:-(ayarlanmamış)}"
}

case "${1:-}" in
    check)   cmd_check ;;
    bind)    cmd_bind ;;
    unbind)  cmd_unbind ;;
    status)  cmd_status ;;
    hugepages) cmd_hugepages ;;
    *)
        cat <<USAGE
Kullanım: $0 {check|bind|unbind|status|hugepages}

Config ($CONF):
  DPDK_ENABLED=yes|no
  DPDK_IFACE=eth1           # YÖNETİM NIC'İ DEĞİL!
  DPDK_DRIVER=vfio-pci      # veya uio_pci_generic
  DPDK_HUGEPAGES=512        # 2MB page sayısı

GÜVENLİK:
  - Yönetim NIC'i ($MGMT_IF) otomatik algılanır ve dokunulmaz
  - DPDK_IFACE = yönetim NIC ise bind reddedilir
  - Interactive onay istenir (EG_DPDK_FORCE=1 ile atlanabilir)

NOT: DPDK ileri seviye tuning için. Çoğu kurulumda XDP yeterlidir.
USAGE
        ;;
esac
