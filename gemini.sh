#!/bin/bash
# ==============================================================================
# CFwarp (warp-yg) 专用：Google / Gemini / YouTube 深度探测与自愈系统 (1Panel/Cron版)
# 自动适配：WireProxy (wireproxy) / Socks5-WARP (warp-svc) / warp-go / wgcf
# 特性：默认 IPv6 优先双栈探测、精准识别端口真实归属进程、防假阳性风控拦截
# ==============================================================================

export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin"
export LANG=en_US.UTF-8

# ----------------- 基础参数配置 -----------------
DEFAULT_SOCKS5_PORT="${DEFAULT_SOCKS5_PORT:-40000}"
WIREPROXY_CONF="${WIREPROXY_CONF:-/etc/wireguard/proxy.conf}"
PREFER_IPV6="${PREFER_IPV6:-true}"
DEBUG_MODE="${DEBUG_MODE:-false}"
TIMEOUT=10
MAX_RETRIES=5

STATE_DIR="/tmp/warp_monitor"
STATS_FILE="${STATE_DIR}/stats.dat"
LOCK_FILE="${STATE_DIR}/monitor.lock"

USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
YT_COOKIES="YSC=BiCUU3-5Gdk; CONSENT=YES+cb.20220301-11-p0.en+FX+700; GPS=1; VISITOR_INFO1_LIVE=4VwPMkB7W5A; PREF=tz=America.Los_Angeles"

WARP_ENDPOINTS_V4=(
    "162.159.192.1:2408"
    "162.159.192.1:500"
    "162.159.193.10:2408"
    "162.159.193.10:500"
    "188.114.96.1:2408"
    "188.114.97.1:2408"
)

WARP_ENDPOINTS_V6=(
    "[2606:4700:d0::a29f:c001]:2408"
    "[2606:4700:d0::a29f:c10a]:2408"
    "[2606:4700:d1::a29f:c001]:2408"
)

# ----------------- 命令行参数解析 -----------------
while [ $# -gt 0 ]; do
    case "$1" in
        --ipv6|-6) PREFER_IPV6="true" ;;
        --ipv4|-4) PREFER_IPV6="false" ;;
        --debug) DEBUG_MODE="true" ;;
        --port)
            shift
            [ -n "$1" ] && DEFAULT_SOCKS5_PORT="$1"
            ;;
    esac
    shift
done

mkdir -p "${STATE_DIR}"

# ----------------- 防并发文件锁 -----------------
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏳ [跳过] 另一个 WARP 巡检任务正在运行中。"
    exit 0
fi

# ----------------- 统计数据读写 -----------------
load_stats() {
    if [ -f "${STATS_FILE}" ]; then
        # shellcheck disable=SC1090
        source "${STATS_FILE}"
    else
        TOTAL_CHECKS=0
        TOTAL_FAILS=0
        TOTAL_HEALS=0
        LAST_FAIL_TIME="None"
    fi
}

save_stats() {
    cat <<EOF > "${STATS_FILE}"
TOTAL_CHECKS=${TOTAL_CHECKS:-0}
TOTAL_FAILS=${TOTAL_FAILS:-0}
TOTAL_HEALS=${TOTAL_HEALS:-0}
LAST_FAIL_TIME="${LAST_FAIL_TIME:-None}"
EOF
}

debug_log() {
    if [ "${DEBUG_MODE}" = "true" ]; then
        echo "[DEBUG $(date '+%H:%M:%S')] $*" >&2
    fi
}

# ----------------- 1. 识别实际代理模式与端口归属进程 -----------------
detect_warp_mode() {
    WARP_MODE=""
    SOCKS5_PORT="${DEFAULT_SOCKS5_PORT}"
    MODE_DESC=""

    local listener_line wp_port warp_port
    listener_line=$(ss -ntlp 2>/dev/null | grep -E "wireproxy|warp-svc" | head -n 1)

    if echo "$listener_line" | grep -q "wireproxy"; then
        WARP_MODE="wireproxy"
        wp_port=$(echo "$listener_line" | awk '{print $4}' | awk -F: '{print $NF}' | grep -E '^[0-9]+$')
        [ -n "$wp_port" ] && SOCKS5_PORT="$wp_port"
        MODE_DESC="WireProxy-WARP (127.0.0.1:${SOCKS5_PORT})"
        return 0
    fi

    if echo "$listener_line" | grep -q "warp-svc"; then
        WARP_MODE="socks5"
        warp_port=$(echo "$listener_line" | awk '{print $4}' | awk -F: '{print $NF}' | grep -E '^[0-9]+$')
        [ -n "$warp_port" ] && SOCKS5_PORT="$warp_port"
        MODE_DESC="Socks5-WARP (127.0.0.1:${SOCKS5_PORT})"
        return 0
    fi

    if [ -f "${WIREPROXY_CONF}" ] && { command -v wireproxy >/dev/null 2>&1 || systemctl list-unit-files 2>/dev/null | grep -q "wireproxy"; }; then
        WARP_MODE="wireproxy"
        wp_port=$(grep -E '^BindAddress\s*=' "${WIREPROXY_CONF}" 2>/dev/null | awk -F: '{print $NF}' | tr -d ' \r\n')
        [ -n "$wp_port" ] && SOCKS5_PORT="$wp_port"
        systemctl start wireproxy >/dev/null 2>&1 || true
        sleep 2
        MODE_DESC="WireProxy-WARP (127.0.0.1:${SOCKS5_PORT})"
        return 0
    fi

    if command -v warp-cli >/dev/null 2>&1; then
        WARP_MODE="socks5"
        if ! systemctl is-active --quiet warp-svc; then
            systemctl start warp-svc >/dev/null 2>&1
            sleep 2
        fi
        warp_port=$(warp-cli --accept-tos settings 2>/dev/null | grep -oP 'WarpProxy on port \K\d+' | head -n 1)
        [ -n "$warp_port" ] && SOCKS5_PORT="$warp_port"
        if ! warp-cli --accept-tos status 2>/dev/null | grep -qi "Connected"; then
            warp-cli --accept-tos connect >/dev/null 2>&1
            sleep 3
        fi
        MODE_DESC="Socks5-WARP (127.0.0.1:${SOCKS5_PORT})"
        return 0
    fi

    if [ -f "/usr/local/bin/warp.conf" ] || command -v warp-go >/dev/null 2>&1; then
        WARP_MODE="warp-go"
        if ! systemctl is-active --quiet warp-go; then
            systemctl restart warp-go >/dev/null 2>&1
            sleep 3
        fi
        MODE_DESC="WARP-GO 全局/分栈接管"
        return 0
    fi

    if [ -f "/etc/wireguard/wgcf.conf" ] || systemctl list-unit-files 2>/dev/null | grep -q "wg-quick@wgcf"; then
        WARP_MODE="wgcf"
        if ! ip link show wgcf >/dev/null 2>&1; then
            systemctl restart wg-quick@wgcf >/dev/null 2>&1
            sleep 3
        fi
        MODE_DESC="WGCF-WARP 全局/分栈接管"
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ [致命错误] 未检测到 wireproxy / warp-cli / warp-go / wgcf，请先运行 cf 安装 WARP！"
    exit 1
}

# ----------------- 2. 协议栈探测与 curl 参数构造 -----------------
resolve_host_ip() {
    local host="$1"
    local family="$2"
    if [ "$family" = "6" ]; then
        getent ahostsv6 "$host" 2>/dev/null | awk 'NR==1{print $1}'
    else
        getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1{print $1}'
    fi
}

build_curl_args() {
    local stack="$1"
    shift
    CURL_ARGS=()

    if [ "$WARP_MODE" = "wireproxy" ] || [ "$WARP_MODE" = "socks5" ]; then
        if [ "$stack" = "auto" ]; then
            CURL_ARGS=(--socks5-hostname "127.0.0.1:${SOCKS5_PORT}")
            return 0
        fi

        local resolved_any=0
        local host ip
        CURL_ARGS=(--socks5 "127.0.0.1:${SOCKS5_PORT}")
        for host in "$@"; do
            ip=$(resolve_host_ip "$host" "$stack")
            if [ -n "$ip" ]; then
                if [ "$stack" = "6" ]; then
                    CURL_ARGS+=(--resolve "${host}:443:[${ip}]")
                else
                    CURL_ARGS+=(--resolve "${host}:443:${ip}")
                fi
                resolved_any=1
            fi
        done

        if [ "$resolved_any" -eq 0 ]; then
            CURL_ARGS=(--socks5-hostname "127.0.0.1:${SOCKS5_PORT}")
        fi
    else
        if [ "$stack" = "6" ]; then
            CURL_ARGS=(-6)
        elif [ "$stack" = "4" ]; then
            CURL_ARGS=(-4)
        fi
    fi
}

fetch_trace_for_stack() {
    local stack="$1"
    local trace
    build_curl_args "$stack" "www.cloudflare.com"
    trace=$(curl -s "${CURL_ARGS[@]}" --connect-timeout 5 --max-time 7 "https://www.cloudflare.com/cdn-cgi/trace" 2>/dev/null)
    CURRENT_IP=$(echo "$trace" | grep -E '^ip=' | cut -d'=' -f2 | tr -d '\r\n')
    CURRENT_LOC=$(echo "$trace" | grep -E '^loc=' | cut -d'=' -f2 | tr -d '\r\n')
    CURRENT_COLO=$(echo "$trace" | grep -E '^colo=' | cut -d'=' -f2 | tr -d '\r\n')
    CURRENT_WARP=$(echo "$trace" | grep -E '^warp=' | cut -d'=' -f2 | tr -d '\r\n')
}

get_warp_network_info() {
    local primary_stack="6"
    local fallback_stack="4"
    if [ "${PREFER_IPV6}" != "true" ]; then
        primary_stack="4"
        fallback_stack="6"
    fi

    ACTIVE_STACK=""
    ACTIVE_STACK_LABEL="未知"

    fetch_trace_for_stack "$primary_stack"
    if [[ "$CURRENT_WARP" =~ ^(on|plus)$ ]] && [ -n "$CURRENT_IP" ]; then
        if { [ "$primary_stack" = "6" ] && [[ "$CURRENT_IP" == *:* ]]; } || \
           { [ "$primary_stack" = "4" ] && [[ "$CURRENT_IP" != *:* ]]; }; then
            ACTIVE_STACK="$primary_stack"
            [ "$primary_stack" = "6" ] && ACTIVE_STACK_LABEL="IPv6" || ACTIVE_STACK_LABEL="IPv4"
            debug_log "Primary stack ${ACTIVE_STACK_LABEL} ok: ip=${CURRENT_IP} colo=${CURRENT_COLO} loc=${CURRENT_LOC}"
            return 0
        fi
    fi

    fetch_trace_for_stack "$fallback_stack"
    if [[ "$CURRENT_WARP" =~ ^(on|plus)$ ]] && [ -n "$CURRENT_IP" ]; then
        ACTIVE_STACK="$fallback_stack"
        [ "$fallback_stack" = "6" ] && ACTIVE_STACK_LABEL="IPv6(回退)" || ACTIVE_STACK_LABEL="IPv4(回退)"
        debug_log "Fallback stack ${ACTIVE_STACK_LABEL} ok: ip=${CURRENT_IP} colo=${CURRENT_COLO} loc=${CURRENT_LOC}"
        return 0
    fi

    fetch_trace_for_stack "auto"
    ACTIVE_STACK="auto"
    if [ -n "$CURRENT_IP" ]; then
        [[ "$CURRENT_IP" == *:* ]] && ACTIVE_STACK_LABEL="IPv6(自动)" || ACTIVE_STACK_LABEL="IPv4(自动)"
    fi
    [ -z "$CURRENT_IP" ] && CURRENT_IP="未知IP"
    [ -z "$CURRENT_LOC" ] && CURRENT_LOC="未知地区"
    [ -z "$CURRENT_COLO" ] && CURRENT_COLO="未知"
    [ -z "$CURRENT_WARP" ] && CURRENT_WARP="off"
}

# ----------------- 3. 五维深度探测 Google / YouTube / Gemini -----------------
check_youtube() {
    local yt_res yt_url yt_code yt_gl yt_hl
    build_curl_args "$ACTIVE_STACK" "www.youtube.com" "consent.youtube.com"
    yt_res=$(curl -sL "${CURL_ARGS[@]}" --connect-timeout "${TIMEOUT}" --max-time "${TIMEOUT}" \
        -H "User-Agent: ${USER_AGENT}" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -b "${YT_COOKIES}" \
        -w "\n__FINAL_URL__:%{url_effective}\n__HTTP_CODE__:%{http_code}" \
        "https://www.youtube.com/premium" 2>/dev/null)

    yt_url=$(echo "$yt_res" | grep "__FINAL_URL__:" | tail -n 1 | cut -d':' -f2- | tr -d '\r\n')
    yt_code=$(echo "$yt_res" | grep "__HTTP_CODE__:" | tail -n 1 | cut -d':' -f2 | tr -d ' \r\n')
    debug_log "YouTube code=${yt_code} url=${yt_url}"

    if [ "$yt_code" = "000" ] || [ -z "$yt_code" ] || [ "$yt_code" -ge 400 ] 2>/dev/null; then
        DIAG_MSG="❌ YouTube 探测异常或被拒绝 (HTTP ${yt_code:-000})"
        return 1
    fi

    if echo "$yt_url" | grep -qi "consent\.youtube\.com"; then
        yt_gl=$(echo "$yt_url" | grep -oP '(?:[?&])gl=\K[A-Za-z]+' | head -n 1 | tr '[:lower:]' '[:upper:]')
        yt_hl=$(echo "$yt_url" | grep -oP '(?:[?&])hl=\K[A-Za-z-]+' | head -n 1 | tr '[:upper:]' '[:lower:]')
        YT_REGION="${yt_gl:-EU}(Consent/${yt_hl:-unknown})"

        if [[ "$yt_hl" =~ ^(ru|zh-cn|be|fa)$ ]] || [[ "$yt_gl" =~ ^(CN|HK|MO|RU|IR|KP|BY|SY|CU)$ ]]; then
            DIAG_MSG="⚠️ YouTube 触发同意页且被判为俄语/受限区 (gl=${yt_gl:-未知}, hl=${yt_hl:-未知})"
            return 1
        fi
        return 0
    fi

    YT_REGION=$(echo "$yt_res" | sed -n 's/.*"contentRegion":"\([^"]*\)".*/\1/p' | head -n 1 | tr -d '\r\n')

    if echo "$yt_res" | grep -q "www.google.cn" || echo "$yt_res" | grep -qiE '"countryCode":"(CN|HK|MO|RU)"'; then
        DIAG_MSG="⚠️ YouTube 接口判定当前 IP 已送中/送俄 (YT区域: ${YT_REGION:-未知})"
        return 1
    fi

    if [[ "$YT_REGION" =~ ^(CN|HK|MO|RU|IR|KP|BY|SY|CU)$ ]]; then
        DIAG_MSG="⚠️ YouTube 归属地处于 Gemini 不支持地区 (YT区域: [${YT_REGION}])"
        return 1
    fi

    if echo "$yt_res" | grep -qiE "Sign in to confirm you.?re not a bot|automated queries"; then
        YT_REGION="Bot拦截"
        DIAG_MSG="⚠️ YouTube 触发人机验证拦截"
        return 1
    fi

    [ -z "$YT_REGION" ] && YT_REGION="200(正常)"
    return 0
}

check_google() {
    local resp_google final_url http_code_google body_size
    build_curl_args "$ACTIVE_STACK" "www.google.com" "accounts.google.com"
    resp_google=$(curl -sL "${CURL_ARGS[@]}" \
        --connect-timeout "${TIMEOUT}" \
        --max-time "${TIMEOUT}" \
        -H "User-Agent: ${USER_AGENT}" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -w "\n__FINAL_URL__:%{url_effective}\n__HTTP_CODE__:%{http_code}" \
        "https://www.google.com/search?q=cloudflare&hl=en" 2>/dev/null)

    final_url=$(echo "$resp_google" | grep "__FINAL_URL__:" | tail -n 1 | cut -d':' -f2- | tr -d '\r\n')
    http_code_google=$(echo "$resp_google" | grep "__HTTP_CODE__:" | tail -n 1 | cut -d':' -f2 | tr -d ' \r\n')
    body_size=${#resp_google}
    debug_log "Google code=${http_code_google} size=${body_size} url=${final_url}"

    if [ "$http_code_google" = "000" ] || [ -z "$http_code_google" ]; then
        DIAG_MSG="❌ Google 搜索服务代理超时/不可达 (HTTP 000)"
        return 1
    fi

    if [ "$http_code_google" = "429" ] || [ "$http_code_google" = "403" ] || [ "$http_code_google" -ge 500 ] 2>/dev/null || \
       echo "$final_url" | grep -qiE "sorry/index|unusual|google\.com/sorry" || \
       echo "$resp_google" | grep -qiE "unusual traffic|reCAPTCHA|detected unusual traffic"; then
        DIAG_MSG="⚠️ 命中 Google 异常流量拦截 (HTTP ${http_code_google} / sorry/reCAPTCHA)"
        return 1
    fi

    GOOGLE_GEO=$(echo "$resp_google" | grep -oP '\[1,null,null,\d+,\d+,"\K[A-Z]{3}' | head -n 1)
    [ -z "$GOOGLE_GEO" ] && GOOGLE_GEO=$(echo "$resp_google" | grep -oP '2,1,200,"\K[A-Z]{3}' | head -n 1)

    if [[ "$GOOGLE_GEO" =~ ^(CHN|HKG|MAC|RUS|IRN|PRK|BLR)$ ]] || \
       echo "$final_url" | grep -qiE "google\.com\.hk|google\.cn|google\.ru" || \
       echo "$resp_google" | grep -qiE '"gl":"(cn|hk|ru)"'; then
        DIAG_MSG="⚠️ Google 搜索底层定位送中/受限 (定位代码: ${GOOGLE_GEO:-受限})"
        return 1
    fi

    if [ -z "$GOOGLE_GEO" ]; then
        if echo "$resp_google" | grep -q "/httpservice/retry/enablejs"; then
            GOOGLE_GEO="JS挑战"
        elif [ "$body_size" -lt 1000 ]; then
            GOOGLE_GEO="异常空页"
            DIAG_MSG="⚠️ Google 搜索返回异常空白页 (HTTP ${http_code_google}, size=${body_size})"
            return 1
        else
            GOOGLE_GEO="200(无代码)"
        fi
    fi
    return 0
}

check_gemini() {
    local resp_gemini gemini_url http_code_gemini
    build_curl_args "$ACTIVE_STACK" "gemini.google.com" "accounts.google.com" "consent.google.com"
    resp_gemini=$(curl -sL "${CURL_ARGS[@]}" \
        --connect-timeout "${TIMEOUT}" \
        --max-time "${TIMEOUT}" \
        -H "User-Agent: ${USER_AGENT}" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -w "\n__FINAL_URL__:%{url_effective}\n__HTTP_CODE__:%{http_code}" \
        "https://gemini.google.com/app" 2>/dev/null)

    gemini_url=$(echo "$resp_gemini" | grep "__FINAL_URL__:" | tail -n 1 | cut -d':' -f2- | tr -d '\r\n')
    http_code_gemini=$(echo "$resp_gemini" | grep "__HTTP_CODE__:" | tail -n 1 | cut -d':' -f2 | tr -d ' \r\n')
    debug_log "Gemini web code=${http_code_gemini} url=${gemini_url}"

    if [ "$http_code_gemini" = "000" ] || [ -z "$http_code_gemini" ]; then
        DIAG_MSG="❌ Gemini 网页代理超时/不可达 (HTTP 000)"
        return 1
    fi

    if [ "$http_code_gemini" -ge 400 ] 2>/dev/null; then
        DIAG_MSG="⚠️ Gemini 网页返回错误状态码 (HTTP ${http_code_gemini})"
        return 1
    fi

    if echo "$gemini_url" | grep -qiE "gemini\.google\.com/faq|unsupported|google\.com/sorry|consent\.google\.com.*hl=ru" || \
       echo "$resp_gemini" | grep -qiE "(不支持.*所在的地区|not supported in your country|not available in your country|country_unavailable|unsupported_country|isn't currently supported|unusual traffic)"; then
        DIAG_MSG="⚠️ 命中 Gemini 网页地区或风控限制 (跳转: ${gemini_url})"
        return 1
    fi

    local resp_api api_code
    build_curl_args "$ACTIVE_STACK" "generativelanguage.googleapis.com"
    resp_api=$(curl -s "${CURL_ARGS[@]}" \
        --connect-timeout "${TIMEOUT}" \
        --max-time "${TIMEOUT}" \
        -w "\n__HTTP_CODE__:%{http_code}" \
        "https://generativelanguage.googleapis.com/v1beta/models" 2>/dev/null)

    api_code=$(echo "$resp_api" | grep "__HTTP_CODE__:" | cut -d':' -f2 | tr -d ' \r\n')
    debug_log "Gemini API code=${api_code}"

    if [ "$api_code" = "000" ] || [ -z "$api_code" ] || [ "$api_code" = "429" ] || [ "$api_code" -ge 500 ] 2>/dev/null; then
        DIAG_MSG="⚠️ Gemini API 接口异常或限流 (HTTP ${api_code:-000})"
        return 1
    fi

    if echo "$resp_api" | grep -qiE "User location is not supported|unsupported_country|FAILED_PRECONDITION"; then
        DIAG_MSG="⚠️ 命中 Gemini API 地区封锁 (User location is not supported)"
        return 1
    fi

    return 0
}

evaluate_network() {
    DIAG_MSG=""
    YT_REGION="未知"
    GOOGLE_GEO="未知"

    if [ "$CURRENT_IP" = "未知IP" ] || [[ ! "$CURRENT_WARP" =~ ^(on|plus)$ ]]; then
        DIAG_MSG="❌ WARP 代理隧道未连通或未生效 (warp=${CURRENT_WARP}, IP=${CURRENT_IP})"
        return 1
    fi

    if [[ "$CURRENT_LOC" =~ ^(CN|HK|MO|RU|IR|KP|BY|SY|CU)$ ]]; then
        DIAG_MSG="⚠️ WARP 出口命中受限国家/地区 (当前 CF LOC: ${CURRENT_LOC})"
        return 1
    fi

    check_youtube || return 1
    check_google || return 1
    check_gemini || return 1

    DIAG_MSG="Google/Gemini/YouTube 核心均无风控拦截，连接正常"
    return 0
}

# ----------------- 4. 分级自愈与强制换 IP（按真实归属进程操作） -----------------
restart_wireproxy_service() {
    if systemctl list-unit-files 2>/dev/null | grep -q "wireproxy"; then
        systemctl restart wireproxy >/dev/null 2>&1
    else
        kill -15 $(pgrep -x wireproxy) >/dev/null 2>&1 || true
        sleep 1
        nohup /usr/bin/wireproxy -c "${WIREPROXY_CONF}" >/dev/null 2>&1 &
    fi
}

restart_warp_core() {
    local current_attempt="${1:-1}"

    if [ "$WARP_MODE" = "wireproxy" ]; then
        if [ "$current_attempt" -eq 1 ]; then
            echo "   -> [WireProxy 模式] 正在重启 wireproxy 服务刷新隧道..."
            restart_wireproxy_service
            sleep 4
        else
            local target_ep ep_idx
            if [ "${PREFER_IPV6}" = "true" ] && ip -6 route get 2606:4700:d0::a29f:c001 >/dev/null 2>&1 && [ "$((current_attempt % 2))" -eq 0 ]; then
                ep_idx=$(( RANDOM % ${#WARP_ENDPOINTS_V6[@]} ))
                target_ep="${WARP_ENDPOINTS_V6[$ep_idx]}"
            else
                ep_idx=$(( RANDOM % ${#WARP_ENDPOINTS_V4[@]} ))
                target_ep="${WARP_ENDPOINTS_V4[$ep_idx]}"
            fi
            echo "   -> [WireProxy 深度自愈] 正在切换 Endpoint (${target_ep}) 并重启 wireproxy..."
            [ -f "${WIREPROXY_CONF}" ] && sed -i "s|^Endpoint\s*=.*|Endpoint = ${target_ep}|" "${WIREPROXY_CONF}"
            restart_wireproxy_service
            sleep 4
        fi

    elif [ "$WARP_MODE" = "socks5" ]; then
        if [ "$current_attempt" -eq 1 ]; then
            echo "   -> [Socks5 模式] 正在断开连接并重启 warp-svc 服务..."
            warp-cli --accept-tos disconnect >/dev/null 2>&1
            systemctl restart warp-svc >/dev/null 2>&1
            sleep 3
            warp-cli --accept-tos connect >/dev/null 2>&1
            sleep 4
        else
            if ! warp-cli --accept-tos account 2>/dev/null | grep -qi "Limited"; then
                echo "   -> [Socks5 深度换 IP] 正在注销旧设备凭证并重新注册全新 WARP 节点 (端口: ${SOCKS5_PORT})..."
                warp-cli --accept-tos disconnect >/dev/null 2>&1
                warp-cli --accept-tos registration delete >/dev/null 2>&1 || warp-cli --accept-tos delete >/dev/null 2>&1
                systemctl restart warp-svc >/dev/null 2>&1
                sleep 2
                echo y | warp-cli --accept-tos registration new >/dev/null 2>&1 || echo y | warp-cli --accept-tos register >/dev/null 2>&1
                warp-cli --accept-tos mode proxy >/dev/null 2>&1 || warp-cli --accept-tos set-mode proxy >/dev/null 2>&1
                warp-cli --accept-tos proxy port "${SOCKS5_PORT}" >/dev/null 2>&1 || warp-cli --accept-tos set-proxy-port "${SOCKS5_PORT}" >/dev/null 2>&1
                warp-cli --accept-tos dns log disable >/dev/null 2>&1 || true
                warp-cli --accept-tos connect >/dev/null 2>&1
                sleep 4
            else
                echo "   -> [Socks5 WARP+ 模式] 检测到 WARP+ 账户，正在深度重启 warp-svc 刷新路由..."
                warp-cli --accept-tos disconnect >/dev/null 2>&1
                systemctl stop warp-svc >/dev/null 2>&1
                sleep 3
                systemctl start warp-svc >/dev/null 2>&1
                sleep 2
                warp-cli --accept-tos connect >/dev/null 2>&1
                sleep 4
            fi
        fi

    elif [ "$WARP_MODE" = "warp-go" ]; then
        local ep_idx=$(( RANDOM % ${#WARP_ENDPOINTS_V4[@]} ))
        local target_ep="${WARP_ENDPOINTS_V4[$ep_idx]}"
        echo "   -> [WARP-GO 模式] 正在切换 Endpoint (${target_ep}) 并重启 warp-go..."
        [ -f /usr/local/bin/warp.conf ] && sed -i "s|^Endpoint\s*=.*|Endpoint = ${target_ep}|" /usr/local/bin/warp.conf
        kill -15 $(pgrep warp-go) >/dev/null 2>&1 || true
        sleep 1
        systemctl restart warp-go >/dev/null 2>&1
        sleep 4

    elif [ "$WARP_MODE" = "wgcf" ]; then
        local ep_idx=$(( RANDOM % ${#WARP_ENDPOINTS_V4[@]} ))
        local target_ep="${WARP_ENDPOINTS_V4[$ep_idx]}"
        echo "   -> [WGCF 模式] 正在切换 Endpoint (${target_ep}) 并重启 wg-quick@wgcf..."
        [ -f /etc/wireguard/wgcf.conf ] && sed -i "s|^Endpoint\s*=.*|Endpoint = ${target_ep}|" /etc/wireguard/wgcf.conf
        wg-quick down wgcf >/dev/null 2>&1 || true
        systemctl restart wg-quick@wgcf >/dev/null 2>&1
        sleep 4
    fi
}

# ==============================================================================
# 主流程
# ==============================================================================
load_stats
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

detect_warp_mode

attempt=1
while [ "$attempt" -le "$MAX_RETRIES" ]; do
    get_warp_network_info

    if evaluate_network; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ [状态健康] ${DIAG_MSG}"
        echo "   📊 运行模式: ${MODE_DESC} [${ACTIVE_STACK_LABEL}] | 出口IP: ${CURRENT_IP} (CF机房:${CURRENT_LOC}/${CURRENT_COLO} / YT归属:${YT_REGION} / Google定位:${GOOGLE_GEO}) | 累计检测:${TOTAL_CHECKS} (自愈:${TOTAL_HEALS})"
        save_stats
        exit 0
    else
        TOTAL_FAILS=$((TOTAL_FAILS + 1))
        LAST_FAIL_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ [触发风控] 尝试 (${attempt}/${MAX_RETRIES}): ${DIAG_MSG}"
        echo "   🔍 当前状态: 模式=${MODE_DESC} [${ACTIVE_STACK_LABEL}] | IP=${CURRENT_IP} | CF机房=${CURRENT_LOC}/${CURRENT_COLO} | YT归属=${YT_REGION} | Google定位=${GOOGLE_GEO}"

        if [ "$attempt" -lt "$MAX_RETRIES" ]; then
            echo "   ⚡ 正在重启/重置 WARP 尝试更换 IP 避开风控..."
            restart_warp_core "$attempt"
            TOTAL_HEALS=$((TOTAL_HEALS + 1))
        fi
        attempt=$((attempt + 1))
    fi
done

save_stats
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚫 [自愈耗尽] 重试 ${MAX_RETRIES} 次后依然命中 Google/Gemini 风控。"
echo "   🛠 排障快照: mode=${WARP_MODE} prefer_ipv6=${PREFER_IPV6} stack=${ACTIVE_STACK_LABEL} port=${SOCKS5_PORT} ip=${CURRENT_IP} loc=${CURRENT_LOC} colo=${CURRENT_COLO} yt=${YT_REGION} google=${GOOGLE_GEO}"
exit 1
