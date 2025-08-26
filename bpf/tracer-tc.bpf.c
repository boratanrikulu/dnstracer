#ifdef __TARGET_ARCH_x86
#include "vmlinux/x86_64.h"
#else
#include "vmlinux/arm64.h"
#endif

#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_endian.h>

// TC action return codes
#define TC_ACT_OK 0
#define TC_ACT_SHOT 2

#include "defs.h"
#include "maps.h"
#include "helpers.h"

char LICENSE[] SEC("license") = "GPL";

// Parse DNS packet from TC context
static __always_inline int parse_dns_packet_tc(struct __sk_buff *skb, struct dns_event *event) {
    u32 offset = 0;
    
    // For TC, we start directly at L3 (IP header)
    struct iphdr ip;
    if (bpf_skb_load_bytes(skb, offset, &ip, sizeof(ip)) < 0)
        return 0;
    
    // Only handle IPv4 UDP packets
    if (ip.version != 4 || ip.protocol != IPPROTO_UDP)
        return 0;
        
    offset += ip.ihl * 4;
    
    struct udphdr udp;
    if (bpf_skb_load_bytes(skb, offset, &udp, sizeof(udp)) < 0)
        return 0;
    offset += sizeof(udp);
    
    // Check if this is DNS traffic (port 53)
    if (udp.dest != bpf_htons(53) && udp.source != bpf_htons(53))
        return 0;
    
    u16 udp_len = bpf_ntohs(udp.len);
    u16 dns_len = udp_len - sizeof(udp);
    
    if (dns_len > 512) dns_len = 512;
    
    event->saddr = ip.saddr;
    event->daddr = ip.daddr;
    event->sport = bpf_ntohs(udp.source);
    event->dport = bpf_ntohs(udp.dest);
    event->dns_len = dns_len;
    
    __builtin_memset(event->dns_data, 0, 512);
    
    if (dns_len > 0 && offset + dns_len <= skb->len) {
        if (bpf_skb_load_bytes(skb, offset, event->dns_data, dns_len) < 0) {
            return 0;
        }
    }
    
    return 1;
}

// TC ingress hook - captures incoming DNS traffic
SEC("tc/ingress")
int dns_ingress(struct __sk_buff *skb) {
    struct dns_event *e = reserve_dns_event();
    if (!e) return TC_ACT_OK;
    
    if (!parse_dns_packet_tc(skb, e)) {
#ifdef USE_RING_BUF
        bpf_ringbuf_discard(e, 0);
#endif
        return TC_ACT_OK;
    }
    
    enum event_type event_type = (e->dport == 53) ? EVENT_TYPE_DNS_QUERY : EVENT_TYPE_DNS_RESPONSE;
    fill_event_header(&e->header, event_type);
    
    send_dns_event(skb, e);
    return TC_ACT_OK;
}

// TC egress hook - captures outgoing DNS traffic  
SEC("tc/egress")
int dns_egress(struct __sk_buff *skb) {
    struct dns_event *e = reserve_dns_event();
    if (!e) return TC_ACT_OK;
    
    if (!parse_dns_packet_tc(skb, e)) {
#ifdef USE_RING_BUF
        bpf_ringbuf_discard(e, 0);
#endif
        return TC_ACT_OK;
    }
    
    enum event_type event_type = (e->dport == 53) ? EVENT_TYPE_DNS_QUERY : EVENT_TYPE_DNS_RESPONSE;
    fill_event_header(&e->header, event_type);
    
    send_dns_event(skb, e);
    return TC_ACT_OK;
}

// Original socket filter (keep for compatibility)
SEC("socket")
int dns_packet_parser(struct __sk_buff *skb) {
    struct dns_event *e = reserve_dns_event();
    if (!e) return 0;
    
    // Use original parsing logic for socket filter
    u32 offset = 0;
    
    struct ethhdr eth;
    if (bpf_skb_load_bytes(skb, offset, &eth, sizeof(eth)) < 0) {
#ifdef USE_RING_BUF
        bpf_ringbuf_discard(e, 0);
#endif
        return 0;
    }
    offset += sizeof(eth);
    
    if (eth.h_proto != bpf_htons(0x0800)) {
#ifdef USE_RING_BUF
        bpf_ringbuf_discard(e, 0);
#endif
        return 0;
    }
    
    struct iphdr ip;
    if (bpf_skb_load_bytes(skb, offset, &ip, sizeof(ip)) < 0) {
#ifdef USE_RING_BUF
        bpf_ringbuf_discard(e, 0);
#endif
        return 0;
    }
    offset += ip.ihl * 4;
    
    if (ip.protocol != IPPROTO_UDP) {
#ifdef USE_RING_BUF
        bpf_ringbuf_discard(e, 0);
#endif
        return 0;
    }
    
    struct udphdr udp;
    if (bpf_skb_load_bytes(skb, offset, &udp, sizeof(udp)) < 0) {
#ifdef USE_RING_BUF
        bpf_ringbuf_discard(e, 0);
#endif
        return 0;
    }
    offset += sizeof(udp);
    
    if (udp.dest != bpf_htons(53) && udp.source != bpf_htons(53)) {
#ifdef USE_RING_BUF
        bpf_ringbuf_discard(e, 0);
#endif
        return 0;
    }
    
    u16 udp_len = bpf_ntohs(udp.len);
    u16 dns_len = udp_len - sizeof(udp);
    
    if (dns_len > 512) dns_len = 512;
    
    e->saddr = ip.saddr;
    e->daddr = ip.daddr;
    e->sport = bpf_ntohs(udp.source);
    e->dport = bpf_ntohs(udp.dest);
    e->dns_len = dns_len;
    
    __builtin_memset(e->dns_data, 0, 512);
    
    if (dns_len > 0 && offset + dns_len <= skb->len) {
        if (bpf_skb_load_bytes(skb, offset, e->dns_data, dns_len) < 0) {
#ifdef USE_RING_BUF
            bpf_ringbuf_discard(e, 0);
#endif
            return 0;
        }
    }
    
    enum event_type event_type = (e->dport == 53) ? EVENT_TYPE_DNS_QUERY : EVENT_TYPE_DNS_RESPONSE;
    fill_event_header(&e->header, event_type);
    
    send_dns_event(skb, e);
    return 0;
}