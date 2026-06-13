#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║   Eagle Guard — XDP Loader / Detacher (v7.1)                         ║
# ║   eBPF/XDP programını NIC'e attach/detach eder                       ║
# ║                                                                      ║
# ║   KRİTİK: SSH ve web trafiği XDP programı tarafından SABİTLE         ║
# ║   XDP_PASS döner — yüklenmesi erişimi kesmez.                        ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -u

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' N='\033[0m'
ok()   { echo -e "${G}  [OK]${N} $*"; }
info() { echo -e "${C}  [..]${N} $*"; }
warn() { echo -e "${Y}  [!!]${N} $*"; }
fail() { echo -e "${R}  [XX]${N} $*"; }

EG_ROOT="/opt/eagle-guard"
XDP_DIR="${EG_ROOT}/xdp"
OBJ="${XDP_DIR}/eagle_xdp.o"
BPF_FS="/sys/fs/bpf/eagle"
CONF="${EG_ROOT}/config/eagle.conf"

# Config oku
[ -f "$CONF" ] && . "$CONF" || true
XDP_IFACE="${XDP_IFACE:-auto}"
XDP_MODE="${XDP_MODE:-generic}"   # generic|native|offload
XDP_ENABLED="${XDP_ENABLED:-no}"
XDP_PPS_LIMIT="${XDP_PPS_LIMIT:-0}"
XDP_SYN_LIMIT="${XDP_SYN_LIMIT:-0}"
ADMIN_PORT_SSH="${ADMIN_PORT_SSH:-22}"
ADMIN_PORT_WEB="${ADMIN_PORT_WEB:-80}"
ADMIN_PORT_WEB2="${ADMIN_PORT_WEB2:-443}"

[ "$(id -u)" != "0" ] && { fail "root gerekli"; exit 1; }

# bpftool var mı
if ! command -v bpftool >/dev/null 2>&1; then
    fail "bpftool bulunamadı — apt install linux-tools-common linux-tools-\$(uname -r) bpftool"
    exit 2
fi

# Default iface bul (default route'daki)
detect_iface() {
    ip -o route show default 2>/dev/null | awk '{print $5; exit}'
}

# bpffs mount
ensure_bpffs() {
    mount | grep -q "type bpf" || mount -t bpf bpf /sys/fs/bpf 2>/dev/null || true
    mkdir -p "$BPF_FS"
}

detach_iface() {
    local IF="$1"
    [ -z "$IF" ] && return 0
    # Her modu dene (hangi yüklüyse)
    ip link set dev "$IF" xdpgeneric off 2>/dev/null || true
    ip link set dev "$IF" xdpdrv     off 2>/dev/null || true
    ip link set dev "$IF" xdpoffload off 2>/dev/null || true
    ip link set dev "$IF" xdp        off 2>/dev/null || true
}

cmd_load() {
    [ "$XDP_ENABLED" != "yes" ] && { warn "XDP devre dışı (config: XDP_ENABLED=no)"; return 0; }
    [ ! -f "$OBJ" ] && { fail "BPF objesi yok: $OBJ — build.sh çalıştır"; return 1; }

    local IF="$XDP_IFACE"
    [ "$IF" = "auto" ] && IF=$(detect_iface)
    [ -z "$IF" ] && { fail "Interface tespit edilemedi"; return 1; }
    ip link show "$IF" >/dev/null 2>&1 || { fail "Interface yok: $IF"; return 1; }

    ensure_bpffs

    # Önce detach (idempotent)
    detach_iface "$IF"

    # Map'leri pin'le (eğer yoksa)
    info "BPF obje yükleniyor: $OBJ"
    # Eski pin'leri temizle
    for m in blacklist_v4 whitelist_v4 hardban_v4 admin_ports ratelimit_v4 cfg_map stats; do
        [ -e "$BPF_FS/$m" ] && rm -f "$BPF_FS/$m"
    done
    [ -e "$BPF_FS/prog" ] && rm -f "$BPF_FS/prog"

    # Programı yükle ve map'leri pin'le
    if ! bpftool prog loadall "$OBJ" "$BPF_FS" type xdp \
         pinmaps "$BPF_FS" 2>/tmp/eagle-xdp-load.err; then
        fail "BPF yükleme başarısız:"
        cat /tmp/eagle-xdp-load.err >&2
        return 3
    fi
    ok "BPF programı ve map'ler pin'lendi: $BPF_FS"

    # Program ID bul
    local PROG_ID
    PROG_ID=$(bpftool prog show pinned "$BPF_FS/eagle_xdp_prog" 2>/dev/null | awk '{print $1}' | tr -d ':')
    if [ -z "$PROG_ID" ]; then
        # Fallback: isme göre ara
        PROG_ID=$(bpftool prog show | grep -B1 eagle_xdp | head -1 | awk '{print $1}' | tr -d ':')
    fi
    [ -z "$PROG_ID" ] && { fail "Program ID alınamadı"; return 4; }

    # NIC'e attach
    local ATTACH_FLAG
    case "$XDP_MODE" in
        native)  ATTACH_FLAG="xdpdrv" ;;
        offload) ATTACH_FLAG="xdpoffload" ;;
        *)       ATTACH_FLAG="xdpgeneric" ;;
    esac

    info "XDP attach: $IF ($XDP_MODE)"
    if ip link set dev "$IF" "$ATTACH_FLAG" pinned "$BPF_FS/eagle_xdp_prog" 2>/tmp/eagle-xdp-att.err; then
        ok "XDP yüklendi: $IF ($XDP_MODE)"
    else
        warn "$XDP_MODE mod başarısız, generic'e düşülüyor..."
        cat /tmp/eagle-xdp-att.err >&2
        if ip link set dev "$IF" xdpgeneric pinned "$BPF_FS/eagle_xdp_prog" 2>/tmp/eagle-xdp-att.err; then
            ok "XDP yüklendi: $IF (generic fallback)"
        else
            fail "XDP attach tamamen başarısız"
            cat /tmp/eagle-xdp-att.err >&2
            # NIC'i clean bırak
            detach_iface "$IF"
            return 5
        fi
    fi

    # Config'i map'e yaz
    bpftool map update pinned "$BPF_FS/cfg_map" key 0 0 0 0 \
        value hex $(printf '%08x' $XDP_PPS_LIMIT | sed 's/../& /g' | awk '{print $4,$3,$2,$1}') \
                  $(printf '%08x' $XDP_SYN_LIMIT | sed 's/../& /g' | awk '{print $4,$3,$2,$1}') \
                  01 00 00 00 2>/dev/null || \
    bpftool map update pinned "$BPF_FS/cfg_map" key 0 0 0 0 \
        value $(printf '%d %d %d %d %d %d %d %d %d %d %d %d' \
            $((XDP_PPS_LIMIT & 0xff)) $(((XDP_PPS_LIMIT>>8) & 0xff)) \
            $(((XDP_PPS_LIMIT>>16) & 0xff)) $(((XDP_PPS_LIMIT>>24) & 0xff)) \
            $((XDP_SYN_LIMIT & 0xff)) $(((XDP_SYN_LIMIT>>8) & 0xff)) \
            $(((XDP_SYN_LIMIT>>16) & 0xff)) $(((XDP_SYN_LIMIT>>24) & 0xff)) \
            1 0 0 0) 2>/dev/null || warn "cfg_map güncelleme başarısız (non-fatal)"

    # Admin portlarını ekle (SSH/HTTP/HTTPS zaten kodda, ama yine de map'e yazalım)
    for p in "$ADMIN_PORT_SSH" "$ADMIN_PORT_WEB" "$ADMIN_PORT_WEB2"; do
        [ -z "$p" ] && continue
        local hi=$(( (p >> 8) & 0xff ))
        local lo=$(( p & 0xff ))
        bpftool map update pinned "$BPF_FS/admin_ports" key $lo $hi value 1 2>/dev/null || true
    done
    ok "Admin portları map'e eklendi: $ADMIN_PORT_SSH $ADMIN_PORT_WEB $ADMIN_PORT_WEB2"

    # Whitelist dosyasını map'e yükle
    if [ -f "${EG_ROOT}/config/whitelist.txt" ]; then
        "$XDP_DIR/eagle-xdp-ctl.sh" whitelist-sync 2>/dev/null || true
    fi

    # İnterface'i kalıcı kaydet (stop için)
    echo "$IF" > "$BPF_FS/.iface" 2>/dev/null || true
    ok "XDP hazır — SSH/web portları SABİTLE korunuyor"
    return 0
}

cmd_unload() {
    local IF
    IF=$(cat "$BPF_FS/.iface" 2>/dev/null || detect_iface)
    if [ -n "$IF" ]; then
        detach_iface "$IF"
        ok "XDP detach: $IF"
    fi
    # pin'leri temizle
    if [ -d "$BPF_FS" ]; then
        for m in blacklist_v4 whitelist_v4 hardban_v4 admin_ports ratelimit_v4 \
                 cfg_map stats eagle_xdp_prog .iface; do
            rm -f "$BPF_FS/$m"
        done
    fi
    ok "BPF pin'leri temizlendi"
}

cmd_status() {
    local IF
    IF=$(cat "$BPF_FS/.iface" 2>/dev/null || detect_iface)
    echo "Interface: ${IF:-?}"
    if [ -n "$IF" ]; then
        ip link show "$IF" | grep -o 'xdp[a-z]*' || echo "XDP: DETACHED"
    fi
    if [ -e "$BPF_FS/eagle_xdp_prog" ]; then
        echo "BPF program: YÜKLÜ ($BPF_FS/eagle_xdp_prog)"
    else
        echo "BPF program: YÜKSÜZ"
    fi
    if [ -e "$BPF_FS/stats" ]; then
        echo "İstatistikler (stat_inc toplamı):"
        bpftool map dump pinned "$BPF_FS/stats" 2>/dev/null | \
            awk '/key:/ {k=$2} /value:/ {
                labels["00"]="PASS"; labels["01"]="DROP_BLACKLIST";
                labels["02"]="DROP_RATELIMIT"; labels["03"]="DROP_MALFORMED";
                labels["04"]="PASS_SSH"; labels["05"]="PASS_WEB";
                labels["06"]="PASS_WHITELIST"; labels["07"]="DROP_HARDBAN";
                printf "  %-18s = %s\n", labels[k], $0
            }' || true
    fi
}

cmd_reload() { cmd_unload; sleep 0.3; cmd_load; }

case "${1:-}" in
    load)    cmd_load ;;
    unload|stop)  cmd_unload ;;
    reload)  cmd_reload ;;
    status)  cmd_status ;;
    *)
        cat <<USAGE
Kullanım: $0 {load|unload|reload|status}

  load    — BPF'yi yükler ve NIC'e attach eder
  unload  — XDP'yi detach eder ve pin'leri temizler
  reload  — unload + load
  status  — Durum + istatistikler

Config: $CONF
  XDP_ENABLED=yes|no
  XDP_IFACE=auto|eth0|...
  XDP_MODE=generic|native|offload
  XDP_PPS_LIMIT=0   (kaynak IP UDP/ICMP pps sınırı, 0=kapalı)
  XDP_SYN_LIMIT=0   (kaynak IP SYN pps sınırı, 0=kapalı)

GÜVENLİK: SSH/HTTP/HTTPS XDP tarafından hiçbir şekilde DROP edilmez.
USAGE
        ;;
esac
