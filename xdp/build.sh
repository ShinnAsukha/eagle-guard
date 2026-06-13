#!/bin/bash
# Eagle Guard XDP build scripti
# Kernel header + clang + libbpf gereksinimleri yoksa uyarır.
set -u
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' N='\033[0m'
ok()   { echo -e "${G}  [OK]${N} $*"; }
info() { echo -e "${C}  [..]${N} $*"; }
warn() { echo -e "${Y}  [!!]${N} $*"; }
fail() { echo -e "${R}  [XX]${N} $*"; }

cd "$(dirname "$0")" || exit 1

MISS=0
for c in clang make bpftool; do
    command -v "$c" >/dev/null 2>&1 && ok "$c bulundu" || { fail "$c eksik"; MISS=1; }
done
[ -f /usr/include/bpf/bpf_helpers.h ] && ok "libbpf headers bulundu" \
    || { fail "libbpf-dev eksik (apt install libbpf-dev)"; MISS=1; }

if [ "$MISS" != "0" ]; then
    cat <<MSG

${Y}XDP bağımlılıkları eksik. Debian/Ubuntu için:${N}
  sudo apt install -y clang llvm libbpf-dev linux-headers-\$(uname -r) \\
       linux-tools-common linux-tools-\$(uname -r) bpftool make gcc

${Y}Bu bağımlılıklar olmadan XDP çalışmaz; iptables datapath'i yine aktif kalır.${N}
MSG
    exit 10
fi

info "BPF objesi derleniyor..."
if make -C . 2>&1 | tee /tmp/eagle-xdp-build.log; then
    [ -f ./eagle_xdp.o ] && ok "eagle_xdp.o hazır" || { fail "obje üretilmedi"; exit 11; }
else
    fail "build başarısız. Log: /tmp/eagle-xdp-build.log"
    exit 12
fi
