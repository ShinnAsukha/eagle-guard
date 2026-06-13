// SPDX-License-Identifier: GPL-2.0
/*
 * Eagle Guard — XDP DDoS mitigation datapath (v7.1)
 *
 * KRİTİK GÜVENLİK İLKESİ:
 *   Bu program SSH (22) ve web (80/443 + özel web portu) trafiğini
 *   HER KOŞULDA geçirir (XDP_PASS). Kaynak IP kara listede olsa bile
 *   yönetim portları bloklanmaz. Yanlış yapılandırma sonucu sysadmin
 *   erişimini kaybetmesin diye bu kural kodda SABİT.
 *
 *   İstisna: src IP "hard_block" map'inde ise — bu map yalnızca
 *   kullanıcı çok özel bir anahtarla (eagle-xdp-ctl hardban) eklenirse
 *   dolar. Normal auto-block akışı buraya dokunmaz.
 *
 * Özellikler:
 *   - LPM trie blacklist (IPv4 prefix bazlı)
 *   - Per-IP SYN/UDP/ICMP pps sayaçları (LRU hash)
 *   - Protokol başlıklarında sınır kontrolü (verifier-safe)
 *   - Whitelist map (kullanıcının "asla dokunma" listesi)
 *   - Global istatistik map'i (drop/pass sayıları)
 *
 * Build:
 *   clang -O2 -g -target bpf -D__TARGET_ARCH_x86 -c eagle_xdp.c -o eagle_xdp.o
 */

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/ipv6.h>
#include <linux/in.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/icmp.h>
#include <linux/pkt_cls.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

/* ─────── Sabit yönetim portları (ASLA BLOKLANMAZ) ─────── */
#define PORT_SSH     22
#define PORT_HTTP    80
#define PORT_HTTPS   443
/* Kullanıcı bu portları eagle-xdp-ctl ile güncelleyebilir (admin_ports map) */

/* ─────── İstatistik indeksleri ─────── */
enum {
    STAT_PASS            = 0,
    STAT_DROP_BLACKLIST  = 1,
    STAT_DROP_RATELIMIT  = 2,
    STAT_DROP_MALFORMED  = 3,
    STAT_PASS_SSH        = 4,
    STAT_PASS_WEB        = 5,
    STAT_PASS_WHITELIST  = 6,
    STAT_DROP_HARDBAN    = 7,
    STAT_MAX
};

/* ─────── Map: IPv4 prefix blacklist (LPM) ─────── */
struct lpm_v4_key {
    __u32 prefixlen;
    __u32 addr;
};

struct {
    __uint(type, BPF_MAP_TYPE_LPM_TRIE);
    __type(key, struct lpm_v4_key);
    __type(value, __u64);      /* ban_until ns timestamp */
    __uint(max_entries, 100000);
    __uint(map_flags, BPF_F_NO_PREALLOC);
} blacklist_v4 SEC(".maps");

/* Whitelist — kullanıcı IP'leri (ASLA bloklanmaz) */
struct {
    __uint(type, BPF_MAP_TYPE_LPM_TRIE);
    __type(key, struct lpm_v4_key);
    __type(value, __u8);
    __uint(max_entries, 10000);
    __uint(map_flags, BPF_F_NO_PREALLOC);
} whitelist_v4 SEC(".maps");

/* Hard-ban — yalnızca "hardban" komutuyla eklenir, yönetim portları dahil bloklar.
 * Normal akışta BOŞ olmalı. */
struct {
    __uint(type, BPF_MAP_TYPE_LPM_TRIE);
    __type(key, struct lpm_v4_key);
    __type(value, __u8);
    __uint(max_entries, 10000);
    __uint(map_flags, BPF_F_NO_PREALLOC);
} hardban_v4 SEC(".maps");

/* Admin port map — PORT_SSH/HTTP/HTTPS dışı ek yönetim portları (örn 8080, 2222) */
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __type(key, __u16);   /* port */
    __type(value, __u8);  /* 1 = admin port */
    __uint(max_entries, 64);
} admin_ports SEC(".maps");

/* Per-IP rate limiter (LRU) */
struct rl_val {
    __u64 window_start_ns;
    __u32 pps;
};

struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __type(key, __u32);         /* src ipv4 */
    __type(value, struct rl_val);
    __uint(max_entries, 200000);
} ratelimit_v4 SEC(".maps");

/* Config map — runtime tunables */
struct config {
    __u32 pps_limit;       /* kaynak başına pps sınırı (0=kapalı) */
    __u32 syn_limit;       /* kaynak başına SYN pps (0=kapalı) */
    __u32 enabled;         /* 0=pass-through mode (metrik topla, düşürme) */
};

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __type(key, __u32);
    __type(value, struct config);
    __uint(max_entries, 1);
} cfg_map SEC(".maps");

/* Stats (per-CPU) */
struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __type(key, __u32);
    __type(value, __u64);
    __uint(max_entries, STAT_MAX);
} stats SEC(".maps");

#define RL_WINDOW_NS  1000000000ULL  /* 1 saniye */

static __always_inline void stat_inc(__u32 idx)
{
    __u64 *v = bpf_map_lookup_elem(&stats, &idx);
    if (v) (*v)++;
}

static __always_inline int is_admin_port(__u16 dport)
{
    if (dport == PORT_SSH || dport == PORT_HTTP || dport == PORT_HTTPS)
        return 1;
    __u8 *v = bpf_map_lookup_elem(&admin_ports, &dport);
    return v ? 1 : 0;
}

static __always_inline int check_ratelimit(__u32 saddr, __u32 limit)
{
    if (!limit) return 0;
    __u64 now = bpf_ktime_get_ns();
    struct rl_val *v = bpf_map_lookup_elem(&ratelimit_v4, &saddr);
    if (!v) {
        struct rl_val nv = { .window_start_ns = now, .pps = 1 };
        bpf_map_update_elem(&ratelimit_v4, &saddr, &nv, BPF_ANY);
        return 0;
    }
    if (now - v->window_start_ns > RL_WINDOW_NS) {
        v->window_start_ns = now;
        v->pps = 1;
        return 0;
    }
    v->pps++;
    return v->pps > limit ? 1 : 0;
}

SEC("xdp")
int eagle_xdp_prog(struct xdp_md *ctx)
{
    void *data_end = (void *)(long)ctx->data_end;
    void *data     = (void *)(long)ctx->data;

    /* Ethernet */
    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end) {
        stat_inc(STAT_DROP_MALFORMED);
        return XDP_DROP;
    }

    __u16 proto = bpf_ntohs(eth->h_proto);

    /* IPv6 — şimdilik her zaman PASS (yönetim güvenliği için) */
    if (proto == ETH_P_IPV6) {
        stat_inc(STAT_PASS);
        return XDP_PASS;
    }

    /* Non-IPv4 trafiği pass (ARP, LLDP, vb.) */
    if (proto != ETH_P_IP) {
        stat_inc(STAT_PASS);
        return XDP_PASS;
    }

    struct iphdr *iph = (void *)(eth + 1);
    if ((void *)(iph + 1) > data_end) {
        stat_inc(STAT_DROP_MALFORMED);
        return XDP_DROP;
    }

    if (iph->ihl < 5) {
        stat_inc(STAT_DROP_MALFORMED);
        return XDP_DROP;
    }

    __u32 saddr = iph->saddr;
    __u8  l4    = iph->protocol;
    __u32 ihl_b = iph->ihl * 4;

    /* L4 başlık sınırı */
    void *l4hdr = (void *)iph + ihl_b;
    if (l4hdr > data_end) {
        stat_inc(STAT_DROP_MALFORMED);
        return XDP_DROP;
    }

    /* Varsayılan dport = 0 */
    __u16 dport = 0;
    __u8  tcp_flags = 0;

    if (l4 == IPPROTO_TCP) {
        struct tcphdr *th = l4hdr;
        if ((void *)(th + 1) > data_end) {
            stat_inc(STAT_DROP_MALFORMED);
            return XDP_DROP;
        }
        dport = bpf_ntohs(th->dest);
        tcp_flags = ((__u8 *)th)[13];   /* flags byte */
    } else if (l4 == IPPROTO_UDP) {
        struct udphdr *uh = l4hdr;
        if ((void *)(uh + 1) > data_end) {
            stat_inc(STAT_DROP_MALFORMED);
            return XDP_DROP;
        }
        dport = bpf_ntohs(uh->dest);
    }

    /* ─── KRİTİK: Whitelist kontrolü ─── */
    struct lpm_v4_key k = { .prefixlen = 32, .addr = saddr };
    if (bpf_map_lookup_elem(&whitelist_v4, &k)) {
        stat_inc(STAT_PASS_WHITELIST);
        return XDP_PASS;
    }

    /* ─── Hard-ban (yönetim portları dahil, özel kullanım) ─── */
    if (bpf_map_lookup_elem(&hardban_v4, &k)) {
        stat_inc(STAT_DROP_HARDBAN);
        return XDP_DROP;
    }

    /* ─── KRİTİK: Yönetim portları koruması ───
     * SSH ve web'i ASLA XDP ile düşürme. iptables/fail2ban katmanı
     * uygun aksiyonu üstlenir. Bu sayede sysadmin erişimi garanti. */
    if (l4 == IPPROTO_TCP && is_admin_port(dport)) {
        if (dport == PORT_SSH) stat_inc(STAT_PASS_SSH);
        else                   stat_inc(STAT_PASS_WEB);
        return XDP_PASS;
    }

    /* Config oku */
    __u32 zero = 0;
    struct config *cfg = bpf_map_lookup_elem(&cfg_map, &zero);
    __u32 pps_limit = cfg ? cfg->pps_limit : 0;
    __u32 syn_limit = cfg ? cfg->syn_limit : 0;
    __u32 enabled   = cfg ? cfg->enabled   : 1;

    /* Pass-through mode: sadece say, düşürme */
    if (!enabled) {
        stat_inc(STAT_PASS);
        return XDP_PASS;
    }

    /* ─── Blacklist (prefix match) ─── */
    __u64 *ban = bpf_map_lookup_elem(&blacklist_v4, &k);
    if (ban) {
        __u64 now = bpf_ktime_get_ns();
        if (*ban == 0 || *ban > now) {
            stat_inc(STAT_DROP_BLACKLIST);
            return XDP_DROP;
        }
        /* süresi geçmiş — pass */
    }

    /* ─── SYN flood ratelimit ─── */
    if (l4 == IPPROTO_TCP && syn_limit) {
        /* SYN flag=0x02, ACK=0x10; sadece SYN tek başınaysa */
        if ((tcp_flags & 0x12) == 0x02) {
            if (check_ratelimit(saddr, syn_limit)) {
                stat_inc(STAT_DROP_RATELIMIT);
                return XDP_DROP;
            }
        }
    }

    /* ─── UDP/ICMP pps ratelimit ─── */
    if ((l4 == IPPROTO_UDP || l4 == IPPROTO_ICMP) && pps_limit) {
        if (check_ratelimit(saddr, pps_limit)) {
            stat_inc(STAT_DROP_RATELIMIT);
            return XDP_DROP;
        }
    }

    stat_inc(STAT_PASS);
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
