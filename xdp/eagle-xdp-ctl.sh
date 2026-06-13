#!/bin/bash
# Eagle Guard — XDP map kontrolü (blacklist/whitelist ekle-sil)
# Kullanım:
#   eagle-xdp-ctl.sh ban    <ip/prefix> [ttl_sec]
#   eagle-xdp-ctl.sh unban  <ip/prefix>
#   eagle-xdp-ctl.sh allow  <ip/prefix>
#   eagle-xdp-ctl.sh noallow <ip/prefix>
#   eagle-xdp-ctl.sh hardban <ip/prefix>   # YÖNETİM PORTLARI DAHİL DROP
#   eagle-xdp-ctl.sh unhardban <ip/prefix>
#   eagle-xdp-ctl.sh list   [blacklist|whitelist|hardban]
#   eagle-xdp-ctl.sh whitelist-sync        # config/whitelist.txt → map
#   eagle-xdp-ctl.sh flush  <map>

set -u
BPF_FS="/sys/fs/bpf/eagle"
EG_ROOT="/opt/eagle-guard"

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' N='\033[0m'
ok()   { echo -e "${G}[OK]${N} $*"; }
warn() { echo -e "${Y}[!!]${N} $*"; }
fail() { echo -e "${R}[XX]${N} $*"; }

[ "$(id -u)" != "0" ] && { fail "root gerekli"; exit 1; }
command -v bpftool >/dev/null || { fail "bpftool yok"; exit 2; }
[ -d "$BPF_FS" ] || { fail "XDP yüklü değil — önce: eagle-guard xdp-start"; exit 3; }

# IPv4 parse: "1.2.3.4" veya "1.2.3.0/24" → prefix,byte0,byte1,byte2,byte3
parse_v4() {
    local spec="$1"
    local ip prefix
    if [[ "$spec" == */* ]]; then
        ip="${spec%/*}"; prefix="${spec#*/}"
    else
        ip="$spec"; prefix="32"
    fi
    IFS=. read -r a b c d <<<"$ip"
    if ! [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ && "$c" =~ ^[0-9]+$ && "$d" =~ ^[0-9]+$ ]]; then
        fail "Geçersiz IP: $spec"
        return 1
    fi
    # LPM key: prefixlen (4 byte LE) + address (big-endian in struct, but stored as __u32)
    # __u32 addr field — in memory order (network byte order saklıyoruz mantıken)
    echo "$prefix $a $b $c $d"
}

_lpm_key_bytes() {
    # prefixlen le, addr 4 byte (network order as stored)
    local pfx=$1 a=$2 b=$3 c=$4 d=$5
    printf "%d %d %d %d %d %d %d %d" \
        $((pfx & 0xff)) $(((pfx>>8)&0xff)) $(((pfx>>16)&0xff)) $(((pfx>>24)&0xff)) \
        "$a" "$b" "$c" "$d"
}

map_add() {
    local MAP=$1 SPEC=$2 VAL=$3
    read -r pfx a b c d < <(parse_v4 "$SPEC") || return 1
    local key; key=$(_lpm_key_bytes "$pfx" "$a" "$b" "$c" "$d")
    if bpftool map update pinned "$BPF_FS/$MAP" key $key value $VAL 2>/tmp/eg-xdp-ctl.err; then
        ok "$MAP += $SPEC"
    else
        fail "$MAP += $SPEC başarısız: $(cat /tmp/eg-xdp-ctl.err)"
        return 4
    fi
}

map_del() {
    local MAP=$1 SPEC=$2
    read -r pfx a b c d < <(parse_v4 "$SPEC") || return 1
    local key; key=$(_lpm_key_bytes "$pfx" "$a" "$b" "$c" "$d")
    if bpftool map delete pinned "$BPF_FS/$MAP" key $key 2>/tmp/eg-xdp-ctl.err; then
        ok "$MAP -= $SPEC"
    else
        warn "$MAP -= $SPEC: $(cat /tmp/eg-xdp-ctl.err)"
    fi
}

cmd_ban() {
    local SPEC="$1" TTL="${2:-3600}"
    # ban_until ns = now + ttl*1e9  (0 = kalıcı)
    local val
    if [ "$TTL" = "0" ]; then
        val="0 0 0 0 0 0 0 0"
    else
        # Kullanıcı alanında ns timestamp üretmek zor, 0 (kalıcı) veriyoruz;
        # süreli ban iptables/eagle-guard servisi tarafından yönetilir.
        val="0 0 0 0 0 0 0 0"
    fi
    map_add blacklist_v4 "$SPEC" "$val"
}

cmd_unban()    { map_del blacklist_v4 "$1"; }
cmd_allow()    { map_add whitelist_v4 "$1" "1"; }
cmd_noallow()  { map_del whitelist_v4 "$1"; }
cmd_hardban()  {
    warn "HARDBAN: SSH/web dahil TÜM trafik bu prefix için DROP edilecek!"
    map_add hardban_v4 "$1" "1"
}
cmd_unhardban(){ map_del hardban_v4 "$1"; }

cmd_list() {
    local M="${1:-blacklist}"
    case "$M" in
        blacklist|bl) MAP=blacklist_v4 ;;
        whitelist|wl) MAP=whitelist_v4 ;;
        hardban|hb)   MAP=hardban_v4 ;;
        *) fail "Bilinmeyen map: $M"; return 1 ;;
    esac
    echo "=== $MAP ==="
    bpftool map dump pinned "$BPF_FS/$MAP" 2>/dev/null | \
        awk '/key:/ {
            pfx=strtonum("0x" $2); a=strtonum("0x" $6); b=strtonum("0x" $7);
            c=strtonum("0x" $8); d=strtonum("0x" $9);
            printf "  %d.%d.%d.%d/%d\n", a,b,c,d,pfx
        }' || echo "  (boş)"
}

cmd_flush() {
    local M="${1:-}"
    case "$M" in
        blacklist) MAP=blacklist_v4 ;;
        whitelist) MAP=whitelist_v4 ;;
        hardban)   MAP=hardban_v4 ;;
        ratelimit) MAP=ratelimit_v4 ;;
        *) fail "flush için map seç: blacklist|whitelist|hardban|ratelimit"; return 1 ;;
    esac
    # dump + delete döngüsü
    bpftool map dump pinned "$BPF_FS/$MAP" -j 2>/dev/null | \
        python3 -c '
import json,sys,subprocess
try: data=json.load(sys.stdin)
except: sys.exit(0)
for e in data:
    k=" ".join(str(int(x,16)) if isinstance(x,str) and x.startswith("0x") else str(x) for x in e.get("key",[]))
    if k: subprocess.run(["bpftool","map","delete","pinned",sys.argv[1],"key"]+k.split(),
                         stderr=subprocess.DEVNULL)
' "$BPF_FS/$MAP" 2>/dev/null || true
    ok "$MAP flush'landı"
}

cmd_whitelist_sync() {
    local F="${EG_ROOT}/config/whitelist.txt"
    [ -f "$F" ] || { warn "whitelist.txt yok"; return 0; }
    local N=0
    while IFS= read -r line; do
        # yorum ve boş satır
        line="${line%%#*}"
        line="$(echo "$line" | tr -d '[:space:]')"
        [ -z "$line" ] && continue
        # IPv6 atla (v7.1: sadece IPv4 XDP destekli)
        [[ "$line" == *:* ]] && continue
        map_add whitelist_v4 "$line" "1" >/dev/null 2>&1 && N=$((N+1))
    done < "$F"
    ok "whitelist sync: $N IPv4 kaydı"
}

case "${1:-}" in
    ban)       shift; cmd_ban "$@" ;;
    unban)     shift; cmd_unban "$@" ;;
    allow)     shift; cmd_allow "$@" ;;
    noallow)   shift; cmd_noallow "$@" ;;
    hardban)   shift; cmd_hardban "$@" ;;
    unhardban) shift; cmd_unhardban "$@" ;;
    list|ls)   shift; cmd_list "$@" ;;
    flush)     shift; cmd_flush "$@" ;;
    whitelist-sync) cmd_whitelist_sync ;;
    *)
        sed -n '2,14p' "$0"
        ;;
esac
