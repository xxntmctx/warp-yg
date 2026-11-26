#!/bin/bash
export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin"
export LANG=en_US.UTF-8

PORT="${1:-40000}"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
YT_CK="YSC=BiCUU3-5Gdk; CONSENT=YES+cb.20220301-11-p0.en+FX+700; GPS=1; VISITOR_INFO1_LIVE=4VwPMkB7W5A; PREF=tz=America.Los_Angeles"

echo "============================================================"
echo "HOST: $(hostname) | TIME: $(date '+%Y-%m-%d %H:%M:%S') | PORT: ${PORT}"
echo "============================================================"

echo "--- [1] 进程、服务与配置拓扑 ---"
echo "gai.conf active:"
grep -nE "^[^#]" /etc/gai.conf 2>/dev/null || echo "(default)"
echo "services:"
for svc in wireproxy warp-svc warp-go v2node xray sing-box; do
    st=$(systemctl is-active "$svc" 2>/dev/null)
    [ -n "$st" ] && echo "  $svc: $st"
done
echo "listeners:"
ss -ntlp 2>/dev/null | grep -E "${PORT}|wireproxy|warp-svc|v2node|xray|sing" || true
if [ -f /etc/wireguard/proxy.conf ]; then
    echo "wireproxy.conf:"
    grep -E "^(BindAddress|Endpoint|MTU)" /etc/wireguard/proxy.conf 2>/dev/null || true
fi
echo "processes:"
ps -eo pid,args 2>/dev/null | grep -E "v2node|xray|sing|wireproxy|warp-svc" | grep -v grep || true
echo "v2node routing/outbound clues:"
find /etc/v2node* /usr/local/v2node* /opt/v2node* /etc/V2bX* 2>/dev/null -maxdepth 3 -type f \( -name "*.json" -o -name "*.yml" -o -name "*.yaml" \) 2>/dev/null | while read -r cfg; do
    echo "  file: $cfg"
    grep -inE "40000|domainStrategy|domain_strategy|strategy|socks|gemini|google|outbound|protocol" "$cfg" 2>/dev/null | grep -ivE "password|token|secret|key|uuid" | head -n 25 || true
done

resolve_ip() {
    local host="$1" fam="$2"
    if [ "$fam" = "6" ]; then
        getent ahostsv6 "$host" 2>/dev/null | awk 'NR==1{print $1}'
    else
        getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1{print $1}'
    fi
}

trace_check() {
    local label="$1"
    shift
    local out
    out=$(curl -s --connect-timeout 5 --max-time 7 "$@" "https://www.cloudflare.com/cdn-cgi/trace" 2>/dev/null | grep -E "^(ip|colo|loc|warp)=" | tr '\n' ' ')
    echo "  $label: ${out:-FAILED}"
}

echo "--- [2] Trace 出口对比 ---"
CF4=$(resolve_ip www.cloudflare.com 4)
CF6=$(resolve_ip www.cloudflare.com 6)
trace_check "Direct IPv4" -4
trace_check "Direct IPv6" -6
trace_check "Socks5h(auto)" --socks5-hostname "127.0.0.1:${PORT}"
[ -n "$CF4" ] && trace_check "Socks5 IPv4" --socks5 "127.0.0.1:${PORT}" --resolve "www.cloudflare.com:443:${CF4}"
[ -n "$CF6" ] && trace_check "Socks5 IPv6" --socks5 "127.0.0.1:${PORT}" --resolve "www.cloudflare.com:443:[${CF6}]"

yt_probe() {
    local label="$1" mode="$2"
    shift 2
    local res code loc final cr
    if [ "$mode" = "bare" ]; then
        res=$(curl -sI --connect-timeout 6 --max-time 8 "$@" "https://www.youtube.com/premium" 2>/dev/null)
        code=$(echo "$res" | head -n 1 | tr -d '\r\n')
        loc=$(echo "$res" | grep -i '^location:' | head -n 1 | tr -d '\r\n')
        echo "  $label (bare): ${code:-TIMEOUT} ${loc}"
    else
        res=$(curl -sL --connect-timeout 6 --max-time 8 -H "User-Agent: ${UA}" -H "Accept-Language: en-US,en;q=0.9" -b "${YT_CK}" "$@" -w "\n__URL__:%{url_effective}\n__CODE__:%{http_code}" "https://www.youtube.com/premium" 2>/dev/null)
        code=$(echo "$res" | grep "__CODE__:" | tail -n 1 | cut -d: -f2 | tr -d ' \r\n')
        final=$(echo "$res" | grep "__URL__:" | tail -n 1 | cut -d: -f2- | tr -d '\r\n')
        cr=$(echo "$res" | sed -n 's/.*"contentRegion":"\([^"]*\)".*/\1/p' | head -n 1)
        echo "  $label (en+ck): code=${code:-000} region=${cr:-none} url=${final}"
    fi
}

echo "--- [3] YouTube 裸请求(看真实IP地区/hl=ru) vs 带Cookie ---"
YT4=$(resolve_ip www.youtube.com 4)
YT6=$(resolve_ip www.youtube.com 6)
yt_probe "Direct IPv4" bare -4
yt_probe "Direct IPv6" bare -6
[ -n "$YT4" ] && yt_probe "Socks5 IPv4" bare --socks5 "127.0.0.1:${PORT}" --resolve "www.youtube.com:443:${YT4}"
[ -n "$YT6" ] && yt_probe "Socks5 IPv6" bare --socks5 "127.0.0.1:${PORT}" --resolve "www.youtube.com:443:[${YT6}]"
[ -n "$YT4" ] && yt_probe "Socks5 IPv4" ck --socks5 "127.0.0.1:${PORT}" --resolve "www.youtube.com:443:${YT4}"
[ -n "$YT6" ] && yt_probe "Socks5 IPv6" ck --socks5 "127.0.0.1:${PORT}" --resolve "www.youtube.com:443:[${YT6}]"

gemini_probe() {
    local label="$1"
    shift
    local res code url size flags
    res=$(curl -sL --connect-timeout 6 --max-time 9 -A "${UA}" -H "Accept-Language: en-US,en;q=0.9" "$@" -w "\n__URL__:%{url_effective}\n__CODE__:%{http_code}\n__SIZE__:%{size_download}" "https://gemini.google.com/app" 2>/dev/null)
    code=$(echo "$res" | grep "__CODE__:" | tail -n 1 | cut -d: -f2 | tr -d ' \r\n')
    url=$(echo "$res" | grep "__URL__:" | tail -n 1 | cut -d: -f2- | tr -d '\r\n')
    size=$(echo "$res" | grep "__SIZE__:" | tail -n 1 | cut -d: -f2 | tr -d ' \r\n')
    flags=$(echo "$res" | grep -oiE "unsupported|not available|isn't currently supported|sorry|unusual traffic|country_unavailable" | sort -u | tr '\n' ',' | sed 's/,$//')
    echo "  $label web: code=${code:-000} size=${size:-0} url=${url} flags=[${flags}]"

    local api_res api_code api_msg
    api_res=$(curl -s --connect-timeout 6 --max-time 8 "$@" -w "\n__CODE__:%{http_code}" "https://generativelanguage.googleapis.com/v1beta/models" 2>/dev/null)
    api_code=$(echo "$api_res" | grep "__CODE__:" | tail -n 1 | cut -d: -f2 | tr -d ' \r\n')
    api_msg=$(echo "$api_res" | grep -iE '"message"|"status"' | head -n 2 | tr -d '\r\n' | cut -c1-140)
    echo "  $label api: code=${api_code:-000} msg=${api_msg}"

    local rpc_res rpc_code
    rpc_res=$(curl -s --connect-timeout 6 --max-time 8 -A "${UA}" -X POST -H "Content-Type: application/x-www-form-urlencoded" --data "f.req=[]" "$@" -w "\n__CODE__:%{http_code}" "https://gemini.google.com/_/BardChatUi/data/batchexecute" 2>/dev/null)
    rpc_code=$(echo "$rpc_res" | grep "__CODE__:" | tail -n 1 | cut -d: -f2 | tr -d ' \r\n')
    echo "  $label rpc: code=${rpc_code:-000} len=${#rpc_res}"
}

echo "--- [4] Gemini Web + API + RPC 对比 ---"
GM4=$(resolve_ip gemini.google.com 4)
GM6=$(resolve_ip gemini.google.com 6)
GL4=$(resolve_ip generativelanguage.googleapis.com 4)
GL6=$(resolve_ip generativelanguage.googleapis.com 6)
gemini_probe "Direct IPv4" -4
gemini_probe "Direct IPv6" -6
[ -n "$GM4" ] && gemini_probe "Socks5 IPv4" --socks5 "127.0.0.1:${PORT}" --resolve "gemini.google.com:443:${GM4}" ${GL4:+--resolve} ${GL4:+"generativelanguage.googleapis.com:443:${GL4}"}
[ -n "$GM6" ] && gemini_probe "Socks5 IPv6" --socks5 "127.0.0.1:${PORT}" --resolve "gemini.google.com:443:[${GM6}]" ${GL6:+--resolve} ${GL6:+"generativelanguage.googleapis.com:443:[${GL6}]"}

echo "--- [5] Google Search & AIStudio 对比 ---"
GG4=$(resolve_ip www.google.com 4)
GG6=$(resolve_ip www.google.com 6)
AS4=$(resolve_ip aistudio.google.com 4)
AS6=$(resolve_ip aistudio.google.com 6)
for pair in "S4:${GG4}:4" "S6:[${GG6}]:6"; do
    tag="${pair%%:*}"
    rest="${pair#*:}"
    ip="${rest%:*}"
    [ -z "$ip" ] || [ "$ip" = "[]" ] && continue
    gres=$(curl -sL --connect-timeout 6 --max-time 8 -A "${UA}" --socks5 "127.0.0.1:${PORT}" --resolve "www.google.com:443:${ip}" -w "\n__CODE__:%{http_code}\n__URL__:%{url_effective}" "https://www.google.com/search?q=cloudflare&hl=en" 2>/dev/null)
    gcode=$(echo "$gres" | grep "__CODE__:" | tail -n 1 | cut -d: -f2 | tr -d ' \r\n')
    gurl=$(echo "$gres" | grep "__URL__:" | tail -n 1 | cut -d: -f2- | tr -d '\r\n')
    gflag=$(echo "$gres" | grep -oiE "/httpservice/retry/enablejs|sorry/index|unusual traffic|reCAPTCHA" | sort -u | tr '\n' ',' | sed 's/,$//')
    echo "  Google $tag: code=${gcode:-000} flags=[${gflag}] url=${gurl}"
done
for pair in "AS4:${AS4}" "AS6:[${AS6}]"; do
    tag="${pair%%:*}"
    ip="${pair#*:}"
    [ -z "$ip" ] || [ "$ip" = "[]" ] && continue
    ares=$(curl -sI -L --connect-timeout 6 --max-time 8 -A "${UA}" --socks5 "127.0.0.1:${PORT}" --resolve "aistudio.google.com:443:${ip}" -w "__CODE__:%{http_code} __URL__:%{url_effective}\n" -o /dev/null "https://aistudio.google.com/" 2>/dev/null | tail -n 1)
    echo "  AIStudio $tag: ${ares}"
done
echo "============================================================"
