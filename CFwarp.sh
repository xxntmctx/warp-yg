#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export LANG=en_US.UTF-8
endpoint=
red='\033[0;31m'
bblue='\033[0;34m'
yellow='\033[0;33m'
green='\033[0;32m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
bblue(){ echo -e "\033[34m\033[01m$1\033[0m";}
rred(){ echo -e "\033[35m\033[01m$1\033[0m";}
readtp(){ read -t5 -n26 -p "$(yellow "$1")" $2;}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "不支持当前的系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
version=$(uname -r | cut -d "-" -f1)
main=$(uname -r | cut -d "." -f1)
minor=$(uname -r | cut -d "." -f2)
vi=$(systemd-detect-virt)
case "$release" in
"Centos") yumapt='yum -y';;
"Ubuntu"|"Debian") yumapt="apt-get -y";;
esac
cpujg(){
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) red "目前脚本不支持$(uname -m)架构" && exit;;
esac
}

cfwarpshow(){
insV=$(cat /root/warpip/v 2>/dev/null)
latestV=$(curl -sL https://raw.githubusercontent.com/xxntmctx/warp-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1)
if [[ -f /root/warpip/v ]]; then
if [ "$insV" = "$latestV" ]; then
echo -e " 当前 CFwarp-yg 脚本版本号：${bblue}${insV}${plain} 已是最新版本"
else
echo -e " 当前 CFwarp-yg 脚本版本号：${bblue}${insV}${plain}"
echo -e " 检测到最新 CFwarp-yg 脚本版本号：${yellow}${latestV}${plain} (可选择8进行更新)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/xxntmctx/warp-yg/main/version)${plain}"
fi
else
echo -e " 当前 CFwarp-yg 脚本版本号：${bblue}${latestV}${plain}"
echo -e " 请先选择方案（1、2、3） ，安装想要的warp模式"
fi
}

tun(){
if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 4
cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit
else
echo '#!/bin/bash' > /root/tun.sh && echo 'cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun' >> /root/tun.sh && chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN守护功能已启动"
fi
fi
fi
}

nf4(){
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
result=$(curl -4fsL --user-agent "${UA_Browser}" --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/70143836" 2>&1)
if [[ "$result" == "404" ]]; then 
NF="遗憾，当前IP仅解锁Netflix自制剧"
elif [[ "$result" == "403" ]]; then
NF="杯具，当前IP不能看Netflix"
elif [[ "$result" == "200" ]]; then
NF="恭喜，当前IP完整解锁Netflix非自制剧"
else
NF="死心吧，Netflix不服务当前IP地区"
fi
}

nf6(){
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
result=$(curl -6fsL --user-agent "${UA_Browser}" --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/70143836" 2>&1)
if [[ "$result" == "404" ]]; then 
NF="遗憾，当前IP仅解锁Netflix自制剧"
elif [[ "$result" == "403" ]]; then
NF="杯具，当前IP不能看Netflix"
elif [[ "$result" == "200" ]]; then
NF="恭喜，当前IP完整解锁Netflix非自制剧"
else
NF="死心吧，Netflix不服务当前IP地区"
fi
}

nfs5() {
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
result=$(curl --user-agent "${UA_Browser}" --write-out %{http_code} --output /dev/null --max-time 10 -sx socks5h://localhost:$mport -4sL "https://www.netflix.com/title/70143836" 2>&1)
if [[ "$result" == "404" ]]; then 
NF="遗憾，当前IP仅解锁Netflix自制剧"
elif [[ "$result" == "403" ]]; then
NF="杯具，当前IP不能看Netflix"
elif [[ "$result" == "200" ]]; then
NF="恭喜，当前IP完整解锁Netflix非自制剧"
else
NF="死心吧，Netflix不服务当前IP地区"
fi
}

v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
}

checkwgcf(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
}

warpip(){
mkdir -p /root/warpip
v4v6
if [[ -z $v4 ]]; then
endpoint=[2606:4700:d0::a29f:c001]:2408
else
endpoint=162.159.192.1:2408
fi
}

dig9(){
if [[ -n $(grep 'DiG 9' /etc/hosts) ]]; then
echo -e "search blue.kundencontroller.de\noptions rotate\nnameserver 2a02:180:6:5::1c\nnameserver 2a02:180:6:5::4\nnameserver 2a02:180:6:5::1e\nnameserver 2a02:180:6:5::1d" > /etc/resolv.conf
fi
}

mtuwarp(){
v4v6
yellow "开始自动设置warp的MTU最佳网络吞吐量值，以优化WARP网络！"
MTUy=1500
MTUc=10
if [[ -n $v6 && -z $v4 ]]; then
ping='ping6'
IP1='2606:4700:4700::1111'
IP2='2001:4860:4860::8888'
else
ping='ping'
IP1='1.1.1.1'
IP2='8.8.8.8'
fi
while true; do
if ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP1} >/dev/null 2>&1 || ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP2} >/dev/null 2>&1; then
MTUc=1
MTUy=$((${MTUy} + ${MTUc}))
else
MTUy=$((${MTUy} - ${MTUc}))
[[ ${MTUc} = 1 ]] && break
fi
[[ ${MTUy} -le 1360 ]] && MTUy='1360' && break
done
MTU=$((${MTUy} - 80))
green "MTU最佳网络吞吐量值= $MTU 已设置完毕"
}

WGproxy(){
curl -sSL https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/acwarp.sh -o acwarp.sh && chmod +x acwarp.sh && bash acwarp.sh
}

xyz(){
if [[ -n $(screen -ls | grep '(Attached)' | awk '{print $1}' | awk -F "." '{print $1}') ]]; then
until [[ -z $(screen -ls | grep '(Attached)' | awk '{print $1}' | awk -F "." '{print $1}' | awk 'NR==1{print}') ]] 
do
Attached=`screen -ls | grep '(Attached)' | awk '{print $1}' | awk -F "." '{print $1}' | awk 'NR==1{print}'`
screen -d $Attached
done
fi
screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null
rm -rf /root/WARP-UP.sh
cat>/root/WARP-UP.sh<<-\EOF
#!/bin/bash
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
sleep 2
checkwgcf(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
}
warpclose(){
wg-quick down wgcf >/dev/null 2>&1;systemctl stop wg-quick@wgcf >/dev/null 2>&1;systemctl disable wg-quick@wgcf >/dev/null 2>&1;kill -15 $(pgrep warp-go) >/dev/null 2>&1;systemctl stop warp-go >/dev/null 2>&1;systemctl disable warp-go >/dev/null 2>&1
}
warpopen(){
wg-quick down wgcf >/dev/null 2>&1;systemctl enable wg-quick@wgcf >/dev/null 2>&1;systemctl start wg-quick@wgcf >/dev/null 2>&1;systemctl restart wg-quick@wgcf >/dev/null 2>&1;kill -15 $(pgrep warp-go) >/dev/null 2>&1;systemctl stop warp-go >/dev/null 2>&1;systemctl enable warp-go >/dev/null 2>&1;systemctl start warp-go >/dev/null 2>&1;systemctl restart warp-go >/dev/null 2>&1
}
warpre(){
i=0
while [ $i -le 4 ]; do let i++
warpopen
checkwgcf
if [[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]]; then
green "中断后的warp尝试获取IP成功！" 
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 中断后的warp尝试获取IP成功！" >> /root/warpip/warp_log.txt
break
else 
red "中断后的warp尝试获取IP失败！"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 中断后的warp尝试获取IP失败！" >> /root/warpip/warp_log.txt
fi
done
checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
warpclose
red "由于5次尝试获取warp的IP失败，现执行停止并关闭warp，VPS恢复原IP状态"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 由于5次尝试获取warp的IP失败，现执行停止并关闭warp，VPS恢复原IP状态" >> /root/warpip/warp_log.txt
fi
}
while true; do
green "检测warp是否启动中…………"
wp=$(cat /root/warpip/wp.log)
if [[ $wp = w4 ]]; then
checkwgcf
if [[ $wgcfv4 =~ on|plus ]]; then
green "恭喜！WARP IPV4状态为运行中！下轮检测将在600秒后自动执行"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 恭喜！WARP IPV4状态为运行中！下轮检测将在600秒后自动执行" >> /root/warpip/warp_log.txt
sleep 600s
else
warpre ; green "下轮检测将在500秒后自动执行"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 下轮检测将在500秒后自动执行" >> /root/warpip/warp_log.txt
sleep 500s
fi
elif [[ $wp = w6 ]]; then
checkwgcf
if [[ $wgcfv6 =~ on|plus ]]; then
green "恭喜！WARP IPV6状态为运行中！下轮检测将在600秒后自动执行"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 恭喜！WARP IPV6状态为运行中！下轮检测将在600秒后自动执行" >> /root/warpip/warp_log.txt
sleep 600s
else
warpre ; green "下轮检测将在500秒后自动执行"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 下轮检测将在500秒后自动执行" >> /root/warpip/warp_log.txt
sleep 500s
fi
else
checkwgcf
if [[ $wgcfv4 =~ on|plus && $wgcfv6 =~ on|plus ]]; then
green "恭喜！WARP IPV4+IPV6状态为运行中！下轮检测将在600秒后自动执行"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 恭喜！WARP IPV4+IPV6状态为运行中！下轮检测将在600秒后自动执行" >> /root/warpip/warp_log.txt
sleep 600s
else
warpre ; green "下轮检测将在500秒后自动执行"
echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] 下轮检测将在500秒后自动执行" >> /root/warpip/warp_log.txt
sleep 500s
fi
fi
done
EOF
[[ -e /root/WARP-UP.sh ]] && screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null ; screen -UdmS up bash -c '/bin/bash /root/WARP-UP.sh'
}

first4(){
mkdir -p /root/warpip
if [[ "$(cat /root/warpip/ip_prefer 2>/dev/null)" == "v6" ]]; then
sed -i '/^precedence ::ffff:0:0\/96  100/d' /etc/gai.conf 2>/dev/null
else
[[ -e /etc/gai.conf ]] && grep -qE '^ *precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf 2>/dev/null
fi
}

toggle_ip_priority(){
mkdir -p /root/warpip
if grep -qE '^ *precedence ::ffff:0:0/96  100' /etc/gai.conf 2>/dev/null; then
yellow "当前系统策略：IPv4 优先 (gai.conf 已启用 ::ffff:0:0/96 100)"
else
green "当前系统策略：IPv6 优先 (系统默认 RFC 6724)"
fi
echo
green "1. 切换为 IPv6 优先（推荐，有利于减少 Google/Gemini/YouTube 风控）"
green "2. 切换为 IPv4 优先"
green "0. 返回上一层"
readp "请选择：" ipprio
case "$ipprio" in
1 )
sed -i '/^precedence ::ffff:0:0\/96  100/d' /etc/gai.conf 2>/dev/null
echo "v6" > /root/warpip/ip_prefer
green "已切换为系统 IPv6 优先！提示：若使用 Xray/sing-box 转发至 40000 端口，请同步开启 UseIPv6 / prefer_ipv6"
;;
2 )
[[ -e /etc/gai.conf ]] && grep -qE '^ *precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf 2>/dev/null
echo "v4" > /root/warpip/ip_prefer
green "已切换为系统 IPv4 优先"
;;
* )
cf
;;
esac
}

gemini_monitor_tool(){
local gscript="/usr/local/bin/warp-gemini-check.sh"
local gurl="https://raw.githubusercontent.com/xxntmctx/warp-yg/main/gemini.sh"
local mconf="/etc/warp-monitor.conf"
local cur_fb="false"
[[ -f "$mconf" ]] && cur_fb=$(grep -E '^AUTO_FALLBACK_DIRECT=' "$mconf" 2>/dev/null | cut -d= -f2 | tr -d '"'\'' \r\n')
[[ -z "$cur_fb" ]] && cur_fb="false"
green "1. 安装/更新并立即执行一次 Google/Gemini/YouTube 深度巡检 (IPv6 优先)"
green "2. 配置每 10 分钟 Cron 自动巡检自愈"
green "3. 卸载 Cron 自动巡检"
green "4. 查看最近巡检日志 (/var/log/warp-gemini.log)"
green "5. 切换 WARP 耗尽时自动降级直连托底 (当前: ${cur_fb})"
green "0. 返回上一层"
readp "请选择：" gopt
case "$gopt" in
1 )
curl -sSL -o "$gscript" "$gurl" && chmod +x "$gscript"
if [[ -s "$gscript" ]]; then
green "脚本已更新至 $gscript，开始执行深度探测……"
bash "$gscript" --ipv6
echo
yellow "1Panel 定时任务可直接填写以下命令："
white "bash $gscript --ipv6"
else
red "下载 gemini.sh 失败，请检查网络"
fi
;;
2 )
[[ ! -s "$gscript" ]] && curl -sSL -o "$gscript" "$gurl" && chmod +x "$gscript"
crontab -l 2>/dev/null | grep -v "warp-gemini-check.sh" > /tmp/crontab.gemini.tmp
echo "*/10 * * * * bash $gscript --ipv6 >> /var/log/warp-gemini.log 2>&1" >> /tmp/crontab.gemini.tmp
crontab /tmp/crontab.gemini.tmp && rm -f /tmp/crontab.gemini.tmp
green "已启用每 10 分钟自动巡检与自愈，日志路径：/var/log/warp-gemini.log"
;;
3 )
crontab -l 2>/dev/null | grep -v "warp-gemini-check.sh" > /tmp/crontab.gemini.tmp
crontab /tmp/crontab.gemini.tmp && rm -f /tmp/crontab.gemini.tmp
green "已移除 Cron 自动巡检任务"
;;
4 )
[[ -f /var/log/warp-gemini.log ]] && tail -n 30 /var/log/warp-gemini.log || yellow "暂无巡检日志"
;;
5 )
local new_fb="true"
[[ "$cur_fb" == "true" ]] && new_fb="false"
touch "$mconf"
sed -i '/^AUTO_FALLBACK_DIRECT=/d' "$mconf" 2>/dev/null
echo "AUTO_FALLBACK_DIRECT=\"${new_fb}\"" >> "$mconf"
green "已将 AUTO_FALLBACK_DIRECT 设置为 ${new_fb} (配置文件: $mconf)"
;;
* )
cf
;;
esac
}

direct_socks5_write_service(){
local dscript="/usr/local/bin/warp-direct-socks5.py"
local dconf="/etc/warp-direct-socks5.conf"
local dsvc="/etc/systemd/system/warp-direct-socks5.service"
local durl="https://raw.githubusercontent.com/xxntmctx/warp-yg/main/direct-socks5.py"
if [[ ! -s "$dscript" ]] || [[ "$1" == "update" ]]; then
curl -sSL -o "$dscript" "$durl" && chmod +x "$dscript"
fi
if [[ ! -s "$dscript" ]]; then
red "下载 direct-socks5.py 失败，请检查网络"
return 1
fi
cat <<EOF > "$dsvc"
[Unit]
Description=CFwarp Direct-Egress SOCKS5 Fallback Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/env python3 ${dscript} --config ${dconf}
Restart=always
RestartSec=2
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
}

direct_socks5_menu(){
local dscript="/usr/local/bin/warp-direct-socks5.py"
local dconf="/etc/warp-direct-socks5.conf"
local cur_port="40000" cur_stack="prefer_v6" cur_dbg="false"
if [[ -f "$dconf" ]]; then
cur_port=$(grep -E '^LISTEN_PORT=' "$dconf" | cut -d= -f2 | tr -d '"'\'' \r\n')
cur_stack=$(grep -E '^STACK_MODE=' "$dconf" | cut -d= -f2 | tr -d '"'\'' \r\n')
cur_dbg=$(grep -E '^DEBUG=' "$dconf" | cut -d= -f2 | tr -d '"'\'' \r\n')
fi
cur_port="${cur_port:-40000}"
cur_stack="${cur_stack:-prefer_v6}"
cur_dbg="${cur_dbg:-false}"
local st="未运行"
systemctl is-active --quiet warp-direct-socks5 && st="运行中"
white "-----------------------------------------------"
yellow "当前直连托底状态：${st} | 端口：127.0.0.1:${cur_port} | 策略：${cur_stack} | Debug：${cur_dbg}"
white "-----------------------------------------------"
green "1. 开启/部署原生直连 Socks5 托底 (自动接管 ${cur_port} 端口，不改 v2node)"
green "2. 切换直连协议栈策略 (prefer_v6 / prefer_v4 / v6_only / v4_only)"
green "3. 修改监听端口"
green "4. 切换 Debug 日志并查看最近运行日志"
green "5. 停用直连托底并恢复官方 Socks5-WARP (warp-svc)"
green "0. 返回上一层"
readp "请选择：" dopt
case "$dopt" in
1 )
readp "监听端口 (回车默认 ${cur_port}):" in_port
cur_port="${in_port:-$cur_port}"
green "请选择出站协议栈策略："
green "1. prefer_v6 (IPv6 优先，失败回退 IPv4，推荐)"
green "2. prefer_v4 (IPv4 优先，失败回退 IPv6)"
green "3. v6_only   (仅 IPv6)"
green "4. v4_only   (仅 IPv4)"
readp "请选择 [1-4] (回车默认 1):" in_st
case "$in_st" in
2 ) cur_stack="prefer_v4";;
3 ) cur_stack="v6_only";;
4 ) cur_stack="v4_only";;
* ) cur_stack="prefer_v6";;
esac
systemctl disable --now wireproxy >/dev/null 2>&1 || true
systemctl stop warp-svc >/dev/null 2>&1 || true
cat <<EOF > "$dconf"
LISTEN_HOST="127.0.0.1"
LISTEN_PORT="${cur_port}"
STACK_MODE="${cur_stack}"
CONNECT_TIMEOUT="6.0"
DEBUG="${cur_dbg}"
EOF
if direct_socks5_write_service update; then
systemctl enable --now warp-direct-socks5 >/dev/null 2>&1
sleep 2
if systemctl is-active --quiet warp-direct-socks5; then
green "原生直连 Socks5 托底已启动 (127.0.0.1:${cur_port}, 策略: ${cur_stack})"
curl -s --max-time 6 --socks5-hostname "127.0.0.1:${cur_port}" https://www.cloudflare.com/cdn-cgi/trace | grep -E "^(ip|colo|loc|warp)="
else
red "warp-direct-socks5 启动失败，请检查 journalctl -u warp-direct-socks5 -n 20"
fi
fi
;;
2 )
green "1. prefer_v6  2. prefer_v4  3. v6_only  4. v4_only"
readp "请选择 [1-4]:" s_choice
case "$s_choice" in
1 ) cur_stack="prefer_v6";;
2 ) cur_stack="prefer_v4";;
3 ) cur_stack="v6_only";;
4 ) cur_stack="v4_only";;
* ) red "无效选择" && return;;
esac
mkdir -p /etc
cat <<EOF > "$dconf"
LISTEN_HOST="127.0.0.1"
LISTEN_PORT="${cur_port}"
STACK_MODE="${cur_stack}"
CONNECT_TIMEOUT="6.0"
DEBUG="${cur_dbg}"
EOF
systemctl restart warp-direct-socks5 >/dev/null 2>&1
green "已切换直连协议栈策略为 ${cur_stack} 并重启服务"
;;
3 )
readp "请输入新端口 [2000-65535]:" new_p
[[ -z "$new_p" ]] && red "未输入端口" && return
cat <<EOF > "$dconf"
LISTEN_HOST="127.0.0.1"
LISTEN_PORT="${new_p}"
STACK_MODE="${cur_stack}"
CONNECT_TIMEOUT="6.0"
DEBUG="${cur_dbg}"
EOF
systemctl restart warp-direct-socks5 >/dev/null 2>&1
green "监听端口已改为 127.0.0.1:${new_p}"
;;
4 )
[[ "$cur_dbg" == "true" ]] && cur_dbg="false" || cur_dbg="true"
cat <<EOF > "$dconf"
LISTEN_HOST="127.0.0.1"
LISTEN_PORT="${cur_port}"
STACK_MODE="${cur_stack}"
CONNECT_TIMEOUT="6.0"
DEBUG="${cur_dbg}"
EOF
systemctl restart warp-direct-socks5 >/dev/null 2>&1
green "Debug 日志已设为 ${cur_dbg}，最近日志如下："
journalctl -u warp-direct-socks5 -n 20 --no-pager 2>/dev/null || true
;;
5 )
systemctl disable --now warp-direct-socks5 >/dev/null 2>&1 || true
if command -v warp-cli >/dev/null 2>&1; then
systemctl enable --now warp-svc >/dev/null 2>&1 || true
sleep 2
warp-cli --accept-tos mode proxy >/dev/null 2>&1 || true
warp-cli --accept-tos proxy port "${cur_port}" >/dev/null 2>&1 || true
warp-cli --accept-tos connect >/dev/null 2>&1 || true
green "已停用直连托底并恢复官方 warp-svc (${cur_port})"
else
yellow "已停用直连托底；当前未安装 warp-cli"
fi
;;
* )
cf
;;
esac
}

docker(){
if [[ -n $(ip a | grep docker) ]]; then
red "检测到VPS已安装docker，请确保docker为host运行模式，否则docker就会失效" && sleep 3s
echo
yellow "6秒后继续安装方案一的WARP，退出安装请按Ctrl+c" && sleep 6s
fi
}

lncf(){
curl -sSL -o /usr/bin/cf -L https://raw.githubusercontent.com/xxntmctx/warp-yg/main/CFwarp.sh
chmod +x /usr/bin/cf
}

UPwpyg(){
if [[ ! -f '/usr/bin/cf' ]]; then
red "未正常安装CFwarp脚本!" && exit
fi
lncf
curl -sL https://raw.githubusercontent.com/xxntmctx/warp-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /root/warpip/v
green "CFwarp脚本升级成功" && cf
}

restwarpgo(){
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
}

cso(){
warp-cli --accept-tos disconnect >/dev/null 2>&1
warp-cli --accept-tos disable-always-on >/dev/null 2>&1
warp-cli --accept-tos delete >/dev/null 2>&1
if [[ $release = Centos ]]; then
yum autoremove cloudflare-warp -y
else
apt purge cloudflare-warp -y
rm -f /etc/apt/sources.list.d/cloudflare-client.list /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
fi
$yumapt autoremove
}

WARPun(){
readp "1.仅卸载方案一 WARP\n2.仅卸载方案二 Socks5-WARP\n3.彻底清理并卸载WARP相关所有方案（1+2）\n 请选择：" cd
case "$cd" in
1 ) cwg && green "warp卸载完成";;
2 ) cso && green "socks5-warp卸载完成";;
3 ) cwg && cso && unreswarp && green "warp与socks5-warp都已彻底卸载完成" && rm -rf /usr/bin/cf warp_update
esac
}

WARPtools(){
wppluskey(){
if [[ $cpu = amd64 ]]; then
curl -sSL -o warpplus.sh --insecure https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/warp_plus.sh >/dev/null 2>&1
elif [[ $cpu = arm64 ]]; then
curl -sSL -o warpplus.sh --insecure https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/warpplusa.sh >/dev/null 2>&1
fi
chmod +x warpplus.sh
timeout 60s ./warpplus.sh
}
green "1. 实时查看WARP在线监测情况（进入前请注意：退出且继续执行监测命令：ctrl+a+d，退出且关闭监测命令：ctrl+c ）"
green "2. 重启WARP在线监测功能"
green "3. 重置并自定义WARP在线监测时间间隔"
green "4. 查看当天WARP在线监测日志"
echo "-----------------------------------------------"
green "5. 更改Socks5+WARP端口"
echo "-----------------------------------------------"
green "6. 用自备的warp密钥，慢慢刷warp+流量"
green "7. 一键生成2000多万GB流量的warp+密钥"
echo "-----------------------------------------------"
green "8. Google/Gemini/YouTube 深度巡检与自愈 (适配1Panel/Cron)"
green "9. 切换系统 IPv4 / IPv6 优先级 (/etc/gai.conf)"
green "10. 原生直连 Socks5 托底管理 (40000 端口直出本机原生 IP)"
echo "-----------------------------------------------"
green "0. 退出"
readp "请选择：" warptools
if [[ $warptools == 1 ]]; then
[[ -z $(type -P warp-go) && -z $(type -P wg-quick) ]] && red "未安装方案一，脚本退出" && exit
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
if [[ $name =~ "up" ]]; then
screen -Ur up
else
red "未启动WARP监测功能，请选择 2 重启" && WARPtools
fi
elif [[ $warptools == 2 ]]; then
[[ -z $(type -P warp-go) && -z $(type -P wg-quick) ]] && red "未安装方案一，脚本退出" && exit
xyz
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
[[ $name =~ "up" ]] && green "WARP在线监测启动成功" || red "WARP在线监测启动失败，查看screen是否安装成功"
elif [[ $warptools == 3 ]]; then
[[ -z $(type -P warp-go) && -z $(type -P wg-quick) ]] && red "未安装方案一，脚本退出" && exit
xyz
readp "warp状态为运行时，重新检测warp状态间隔时间（回车默认600秒）,请输入间隔时间（例：50秒，输入50）:" stop
[[ -n $stop ]] && sed -i "s/600s/${stop}s/g;s/600秒/${stop}秒/g" /root/WARP-UP.sh || green "默认间隔600秒"
readp "warp状态为中断时(连续5次失败自动关闭warp，恢复原VPS的IP)，继续检测WARP状态间隔时间（回车默认500秒）,请输入间隔时间（例：50秒，输入50）:" goon
[[ -n $goon ]] && sed -i "s/500s/${goon}s/g;s/500秒/${goon}秒/g" /root/WARP-UP.sh || green "默认间隔500秒"
[[ -e /root/WARP-UP.sh ]] && screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null ; screen -UdmS up bash -c '/bin/bash /root/WARP-UP.sh'
green "设置完成，可在选项1查看监测时间间隔"
elif [[ $warptools == 4 ]]; then
[[ -z $(type -P warp-go) && -z $(type -P wg-quick) ]] && red "未安装方案一，脚本退出" && exit
cat /root/warpip/warp_log.txt
# find /root/warpip/warp_log.txt -mtime -1 -exec cat {} \;
elif [[ $warptools == 6 ]]; then
green "也可以在线网页端刷：https://replit.com/@ygkkkk/Warp" && sleep 2
wget -N https://gitlab.com/rwkgyg/CFwarp/raw/main/wp-plus.py 
sed -i "27 s/[(][^)]*[)]//g" wp-plus.py
readp "客户端配置ID(36个字符)：" ID
sed -i "27 s/input/'$ID'/" wp-plus.py
python3 wp-plus.py
elif [[ $warptools == 5 ]]; then
SOCKS5WARPPORT
elif [[ $warptools == 7 ]]; then
wppluskey && rm -rf warpplus.sh
green "当前脚本累计已生成的warp+密钥已放置在/root/WARP+Keys.txt文件内"
green "每重新执行一次的新密钥将放置在文件末尾（包括方案一与方案二）"
blue "$(cat /root/WARP+Keys.txt)"
echo
elif [[ $warptools == 8 ]]; then
gemini_monitor_tool
elif [[ $warptools == 9 ]]; then
toggle_ip_priority
elif [[ $warptools == 10 ]]; then
direct_socks5_menu
else
cf
fi
}

chatgpt4(){
gpt1=$(curl -s4 https://chat.openai.com 2>&1)
gpt2=$(curl -s4 https://ios.chat.openai.com 2>&1)
}
chatgpt6(){
gpt1=$(curl -s6 https://chat.openai.com 2>&1)
gpt2=$(curl -s6 https://ios.chat.openai.com 2>&1)
}
checkgpt(){
#if [[ $gpt1 == *location* ]]; then
if [[ $gpt2 == *VPN* ]]; then
chat='遗憾，当前IP仅解锁ChatGPT网页，未解锁客户端'
elif [[ $gpt2 == *Request* ]]; then
chat='恭喜，当前IP完整解锁ChatGPT (网页+客户端)'
else
chat='杯具，当前IP无法解锁ChatGPT服务'
fi
#else
#chat='杯具，当前IP无法解锁ChatGPT服务'
#fi
}

get_ip_geo_info(){
local target_ip="$1"
local proxy_port="$2"
local proxy_opt=""
[[ -n "$proxy_port" ]] && proxy_opt="-x socks5h://localhost:$proxy_port"
local json1 json2
json1=$(curl -sm3 $proxy_opt --user-agent "${UA_Browser}" "http://ip-api.com/json/${target_ip}?lang=zh-CN" -k 2>/dev/null)
if command -v python3 >/dev/null 2>&1; then
geo_country=$(python3 -c 'import sys,json
try:
 d=json.load(sys.stdin); print(d.get("country","") if d.get("status")=="success" else "")
except Exception: pass' <<< "$json1")
geo_isp=$(python3 -c 'import sys,json
try:
 d=json.load(sys.stdin); print(d.get("isp","") or d.get("org","") if d.get("status")=="success" else "")
except Exception: pass' <<< "$json1")
if [[ -z "$geo_isp" || -z "$geo_country" ]]; then
json2=$(curl -sm3 $proxy_opt --user-agent "${UA_Browser}" "https://api.ip.sb/geoip/${target_ip}" -k 2>/dev/null)
[[ -z "$geo_isp" ]] && geo_isp=$(python3 -c 'import sys,json
try:
 d=json.load(sys.stdin); print(d.get("isp","") or d.get("organization","") or d.get("asn_organization",""))
except Exception: pass' <<< "$json2")
[[ -z "$geo_country" ]] && geo_country=$(python3 -c 'import sys,json
try:
 d=json.load(sys.stdin); print(d.get("country",""))
except Exception: pass' <<< "$json2")
fi
else
geo_country=$(echo "$json1" | sed -n 's/.*"country":"\([^"]*\)".*/\1/p' | head -n 1)
geo_isp=$(echo "$json1" | sed -n 's/.*"isp":"\([^"]*\)".*/\1/p' | head -n 1)
fi
[[ -z "$geo_isp" ]] && geo_isp="未知"
[[ -z "$geo_country" ]] && geo_country="未知"
}

check_gemini_unlock(){
local -a c_args=("$@")
local web_res web_url web_code api_res api_code yt_url
web_res=$(curl -sL "${c_args[@]}" --connect-timeout 6 --max-time 8 -A "${UA_Browser}" -w "\n__URL__:%{url_effective}\n__CODE__:%{http_code}" "https://gemini.google.com/app" 2>/dev/null)
web_url=$(echo "$web_res" | grep "__URL__:" | tail -n 1 | cut -d':' -f2- | tr -d '\r\n')
web_code=$(echo "$web_res" | grep "__CODE__:" | tail -n 1 | cut -d':' -f2 | tr -d ' \r\n')
if [[ -z "$web_code" || "$web_code" == "000" ]]; then
gemini='杯具，当前IP无法连接Gemini服务'
return
fi
if [[ "$web_code" -ge 400 ]] 2>/dev/null || echo "$web_url" | grep -qiE "gemini\.google\.com/faq|unsupported|google\.com/sorry|consent\.google\.com.*hl=ru" || echo "$web_res" | grep -qiE "(不支持.*所在的地区|not supported in your country|not available in your country|country_unavailable|unsupported_country|isn't currently supported|unusual traffic)"; then
gemini="杯具，当前IP受限于Gemini地区或风控 (HTTP ${web_code})"
return
fi
local wiz_tz wiz_cc hel_off cf_loc_now
cf_loc_now=$(curl -s "${c_args[@]}" --connect-timeout 4 --max-time 5 "https://www.cloudflare.com/cdn-cgi/trace" 2>/dev/null | grep -E '^loc=' | cut -d= -f2 | tr -d '\r\n')
wiz_tz=$(echo "$web_res" | grep -oP '"rtQCxc":\s*\K-?\d+' | head -n 1)
wiz_cc=$(echo "$web_res" | grep -oP '"vXmutd":"[^"]*?\\"\K[A-Z]{2}(?=\\")' | head -n 1)
if [[ "$wiz_cc" =~ ^(CN|HK|MO|RU|IR|KP|BY|SY|CU)$ ]]; then
gemini="杯具，Gemini画像国家受限 (${wiz_cc})"
return
fi
if [[ "$wiz_tz" == "-180" ]]; then
hel_off=$(TZ=Europe/Helsinki date +%z 2>/dev/null || echo "")
if [[ "$cf_loc_now" =~ ^(DE|NL|FR|GB|SE|NO|DK|PL|CZ|AT|CH|IT|ES|PT|US|CA|AU|JP|SG|KR|TW)$ ]] || [[ "$cf_loc_now" == "FI" && "$hel_off" == "+0200" ]]; then
gemini="遗憾，当前IP被Gemini识别为俄区时区 (rtQCxc=-180)"
return
fi
fi
api_res=$(curl -s "${c_args[@]}" --connect-timeout 6 --max-time 8 -w "\n__CODE__:%{http_code}" "https://generativelanguage.googleapis.com/v1beta/models" 2>/dev/null)
api_code=$(echo "$api_res" | grep "__CODE__:" | tail -n 1 | cut -d':' -f2 | tr -d ' \r\n')
if [[ -z "$api_code" || "$api_code" == "000" || "$api_code" == "429" ]] || [[ "$api_code" -ge 500 ]] 2>/dev/null; then
gemini="遗憾，Gemini API异常或限流 (HTTP ${api_code:-000})"
return
fi
if echo "$api_res" | grep -qiE "User location is not supported|unsupported_country|FAILED_PRECONDITION"; then
gemini='杯具，当前IP命中Gemini API地区封锁'
return
fi
yt_url=$(curl -sI "${c_args[@]}" --connect-timeout 5 --max-time 6 -A "${UA_Browser}" "https://www.youtube.com/premium" 2>/dev/null | grep -i '^location:' | head -n 1 | tr -d '\r\n')
if echo "$yt_url" | grep -qiE "consent\.youtube\.com.*([?&]hl=ru|[?&]gl=(CN|HK|MO|RU|IR|KP|BY))"; then
gemini='遗憾，当前IP已被Google/YouTube标记俄语(hl=ru)或受限区'
return
fi
gemini='恭喜，当前IP完整解锁Gemini (网页+API)'
}

gemini4(){
check_gemini_unlock -4
}

gemini6(){
check_gemini_unlock -6
}

ShowSOCKS5(){
local s5_listener s5_owner="none" s5_port="" d_stack="prefer_v6"
if systemctl is-active --quiet warp-direct-socks5 2>/dev/null || pgrep -f "warp-direct-socks5\.py" >/dev/null 2>&1; then
s5_owner="direct-socks5"
if [[ -f /etc/warp-direct-socks5.conf ]]; then
s5_port=$(grep -E '^LISTEN_PORT=' /etc/warp-direct-socks5.conf | cut -d= -f2 | tr -d '"'\'' \r\n')
d_stack=$(grep -E '^STACK_MODE=' /etc/warp-direct-socks5.conf | cut -d= -f2 | tr -d '"'\'' \r\n')
fi
else
s5_listener=$(ss -ntlp 2>/dev/null | grep -E "wireproxy|warp-svc" | head -n 1)
if echo "$s5_listener" | grep -q "wireproxy"; then
s5_owner="wireproxy"
s5_port=$(echo "$s5_listener" | awk '{print $4}' | awk -F: '{print $NF}')
elif [[ $(systemctl is-active warp-svc 2>/dev/null) = active ]]; then
s5_owner="warp-svc"
s5_port=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
fi
fi
mport="${s5_port:-40000}"
if [[ "$s5_owner" != "none" ]]; then
local s5ip4 s5ip6 cf_v4 cf_v6
cf_v4=$(getent ahostsv4 www.cloudflare.com 2>/dev/null | awk 'NR==1{print $1}')
cf_v6=$(getent ahostsv6 www.cloudflare.com 2>/dev/null | awk 'NR==1{print $1}')
[[ -n "$cf_v4" ]] && s5ip4=$(curl -s --max-time 4 --socks5 127.0.0.1:$mport --resolve "www.cloudflare.com:443:${cf_v4}" https://www.cloudflare.com/cdn-cgi/trace | grep -E '^ip=' | cut -d= -f2 | tr -d '\r\n')
[[ -n "$cf_v6" ]] && s5ip6=$(curl -s --max-time 4 --socks5 127.0.0.1:$mport --resolve "www.cloudflare.com:443:[${cf_v6}]" https://www.cloudflare.com/cdn-cgi/trace | grep -E '^ip=' | cut -d= -f2 | tr -d '\r\n')
s5ip="${s5ip6:-$s5ip4}"
[[ -z "$s5ip" ]] && s5ip=$(curl -sx socks5h://localhost:$mport icanhazip.com -k 2>/dev/null)
nfs5
gpt1=$(curl -sx socks5h://localhost:$mport https://chat.openai.com 2>&1)
gpt2=$(curl -sx socks5h://localhost:$mport https://android.chat.openai.com 2>&1)
checkgpt
if [[ "$s5_owner" == "direct-socks5" ]]; then
check_gemini_unlock -x "socks5h://localhost:$mport"
elif [[ -n "$s5ip6" ]]; then
local g_v6 gl_v6 yt_v6
g_v6=$(getent ahostsv6 gemini.google.com 2>/dev/null | awk 'NR==1{print $1}')
gl_v6=$(getent ahostsv6 generativelanguage.googleapis.com 2>/dev/null | awk 'NR==1{print $1}')
yt_v6=$(getent ahostsv6 www.youtube.com 2>/dev/null | awk 'NR==1{print $1}')
local -a s5_gem_args=(--socks5 "127.0.0.1:$mport")
[[ -n "$g_v6" ]] && s5_gem_args+=(--resolve "gemini.google.com:443:[$g_v6]")
[[ -n "$gl_v6" ]] && s5_gem_args+=(--resolve "generativelanguage.googleapis.com:443:[$gl_v6]")
[[ -n "$yt_v6" ]] && s5_gem_args+=(--resolve "www.youtube.com:443:[$yt_v6]")
check_gemini_unlock "${s5_gem_args[@]}"
else
check_gemini_unlock -x "socks5h://localhost:$mport"
fi
get_ip_geo_info "$s5ip" "$mport"
country="$geo_country"
socks5=$(curl -sx socks5h://localhost:$mport www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 2 | grep warp | cut -d= -f2)
local ip_disp="${s5ip}  ${country}"
[[ -n "$s5ip4" && -n "$s5ip6" ]] && ip_disp="v6:${s5ip6} | v4:${s5ip4} (${country})"
local owner_note=""
[[ "$s5_owner" == "wireproxy" ]] && owner_note=" [实际托管: wireproxy]"
if [[ "$s5_owner" == "direct-socks5" ]]; then
S5Status=$(white "Socks5 托底状态：\c" ; green "运行中 [原生直连模式: ${d_stack:-prefer_v6}]，跳过WARP污染池" ; white " Socks5 端口：\c" ; green "$mport" ; white " 原生直连出口IP：\c" ; green "$ip_disp" ; white " 奈飞NF解锁情况：\c" ; green "$NF" ; white " ChatGPT解锁情况：\c" ; green "$chat" ; white " Gemini解锁情况：\c" ; green "$gemini")
else
case ${socks5} in
plus)
S5Status=$(white "Socks5 WARP+状态：\c" ; rred "运行中${owner_note}，WARP+账户(剩余WARP+流量：$((`warp-cli --accept-tos account 2>/dev/null | grep Quota | awk '{ print $(NF) }'`/1000000000)) GB)" ; white " Socks5 端口：\c" ; rred "$mport" ; white " 服务商 Cloudflare 出口IP：\c" ; rred "$ip_disp" ; white " 奈飞NF解锁情况：\c" ; rred "$NF" ; white " ChatGPT解锁情况：\c" ; rred "$chat" ; white " Gemini解锁情况：\c" ; rred "$gemini");;
on)
S5Status=$(white "Socks5 WARP状态：\c" ; green "运行中${owner_note}，WARP普通账户(无限WARP流量)" ; white " Socks5 端口：\c" ; green "$mport" ; white " 服务商 Cloudflare 出口IP：\c" ; green "$ip_disp" ; white " 奈飞NF解锁情况：\c" ; green "$NF" ; white " ChatGPT解锁情况：\c" ; green "$chat" ; white " Gemini解锁情况：\c" ; green "$gemini");;
*)
S5Status=$(white "Socks5 WARP状态：\c" ; yellow "已安装Socks5-WARP客户端，但端口处于关闭状态")
esac
fi
else
S5Status=$(white "Socks5 WARP状态：\c" ; red "未安装Socks5-WARP客户端")
fi
}

SOCKS5ins(){
yellow "检测Socks5-WARP安装环境中……"
if [[ $release = Centos ]]; then
[[ ! ${vsid} =~ 8 ]] && yellow "当前系统版本号：Centos $vsid \nSocks5-WARP仅支持Centos 8 " && exit 
elif [[ $release = Ubuntu ]]; then
[[ ! ${vsid} =~ 20|22|24 ]] && yellow "当前系统版本号：Ubuntu $vsid \nSocks5-WARP仅支持 Ubuntu 20.04/22.04/24.04系统 " && exit 
elif [[ $release = Debian ]]; then
[[ ! ${vsid} =~ 10|11|12|13 ]] && yellow "当前系统版本号：Debian $vsid \nSocks5-WARP仅支持 Debian 10/11/12/13系统 " && exit 
fi
[[ $(warp-cli --accept-tos status 2>/dev/null) =~ 'Connected' ]] && red "当前Socks5-WARP已经在运行中" && cf

systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
v4v6
if [[ -n $v6 && -z $v4 ]]; then
systemctl start wg-quick@wgcf >/dev/null 2>&1
restwarpgo
red "纯IPV6的VPS目前不支持安装Socks5-WARP" && sleep 2 && exit
else
systemctl start wg-quick@wgcf >/dev/null 2>&1
restwarpgo
#elif [[ -n $v4 && -z $v6 ]]; then
#systemctl start wg-quick@wgcf >/dev/null 2>&1
#checkwgcf
#[[ $wgcfv4 =~ on|plus ]] && red "纯IPV4的VPS已安装Wgcf-WARP-IPV4，不支持安装Socks5-WARP" && cf
#elif [[ -n $v4 && -n $v6 ]]; then
#systemctl start wg-quick@wgcf >/dev/null 2>&1
#checkwgcf
#[[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]] && red "原生双栈VPS已安装Wgcf-WARP-IPV4/IPV6，请先卸载。然后安装Socks5-WARP，最后安装Wgcf-WARP-IPV4/IPV6" && cf
fi
#systemctl start wg-quick@wgcf >/dev/null 2>&1
#checkwgcf
#if [[ $wgcfv4 =~ on|plus && $wgcfv6 =~ on|plus ]]; then
#red "已安装Wgcf-WARP-IPV4+IPV6，不支持安装Socks5-WARP" && cf
#fi
if [[ $release = Centos ]]; then 
yum -y install epel-release && yum -y install net-tools
curl -fsSl https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo | tee /etc/yum.repos.d/cloudflare-warp.repo
yum update
#rpm -ivh https://pkg.cloudflareclient.com/cloudflare-release-el8.rpm
yum -y install cloudflare-warp
fi
if [[ $release = Debian ]]; then
[[ ! $(type -P gpg) ]] && apt update && apt install gnupg -y
[[ ! $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]] && apt update && apt install apt-transport-https -y
fi
if [[ $release != Centos ]]; then 
apt install net-tools -y
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install cloudflare-warp
fi

# Added: 屏蔽 warp-svc 日志写盘以优化磁盘 I/O Wait
systemctl stop warp-svc >/dev/null 2>&1
rm -rf /var/log/cloudflare-warp/*
ln -sf /dev/null /var/log/cloudflare-warp/cfwarp_service_log.txt
ln -sf /dev/null /var/log/cloudflare-warp/cfwarp_service_connection_stats.txt
ln -sf /dev/null /var/log/cloudflare-warp/cfwarp_service_network_health_stats.txt
ln -sf /dev/null /var/log/cloudflare-warp/cfwarp_route_change_log.txt
ln -sf /dev/null /var/log/cloudflare-warp/cfwarp_service_taskdump.txt
systemctl start warp-svc >/dev/null 2>&1

warpip
echo y | warp-cli registration new
warp-cli mode proxy 
warp-cli proxy port 40000
warp-cli connect
warp-cli dns log disable >/dev/null 2>&1
#wppluskey >/dev/null 2>&1
#ID=$(tail -n1 /root/WARP+Keys.txt | cut -d' ' -f1 2>/dev/null)
#if [[ -n $ID ]]; then
#green "使用warp+密钥"
#green "$(tail -n1 /root/WARP+Keys.txt | cut -d' ' -f1)"
#warp-cli --accept-tos set-license $ID >/dev/null 2>&1
#fi
#rm -rf warpplus.sh
#if [[ $(warp-cli --accept-tos account) =~ 'Limited' ]]; then
#green "已升级为Socks5-WARP+账户\nSocks5-WARP+账户剩余流量：$((`warp-cli --accept-tos account | grep Quota | awk '{ print $(NF) }'`/1000000000)) GB"
#fi
green "安装结束，回到菜单"
sleep 2 && lncf && reswarp && cf
}

SOCKS5WARPUP(){
[[ ! $(type -P warp-cli) ]] && red "未安装Socks5-WARP，无法升级到Socks5-WARP+账户" && exit
[[ $(warp-cli --accept-tos account) =~ 'Limited' ]] && red "当前已是Socks5-WARP+账户，无须再升级" && exit
readp "按键许可证秘钥(26个字符):" ID
[[ -n $ID ]] && warp-cli --accept-tos set-license $ID >/dev/null 2>&1 || (red "未输入按键许可证秘钥(26个字符)" && exit)
yellow "如提示Error: Too many devices.可能绑定设备已超过5台的限制或者密钥输入错误"
if [[ $(warp-cli --accept-tos account) =~ 'Limited' ]]; then
green "已升级为Socks5-WARP+账户\nSocks5-WARP+账户剩余流量：$((`warp-cli --accept-tos account | grep Quota | awk '{ print $(NF) }'`/1000000000)) GB"
else
red "升级Socks5-WARP+账户失败" && exit
fi
sleep 2 && ShowSOCKS5 && S5menu
}

SOCKS5WARPPORT(){
[[ ! $(type -P warp-cli) ]] && red "未安装Socks5-WARP(+)，无法更改端口" && exit
readp "请输入自定义socks5端口[2000～65535]（回车跳过为2000-65535之间的随机端口）:" port
if [[ -z $port ]]; then
port=$(shuf -i 2000-65535 -n 1)
until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义socks5端口:" port
done
else
until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义socks5端口:" port
done
fi
[[ -n $port ]] && warp-cli set-proxy-port $port >/dev/null 2>&1
green "当前socks5端口：$port"
sleep 2 && ShowSOCKS5 && S5menu
}

WGCFmenu(){
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
[[ $name =~ "up" ]] && keepup="WARP监测已开启" || keepup="WARP监测关闭中"
white "------------------------------------------------------------------------------------"
white " 方案一：当前 IPV4 接管VPS出站情况如下（$keepup）"
white " ${WARPIPv4Status}"
white "------------------------------------------------------------------------------------"
white " 方案一：当前 IPV6 接管VPS出站情况如下（$keepup）"
white " ${WARPIPv6Status}"
white "------------------------------------------------------------------------------------"
if [[ "$WARPIPv4Status" == *不存在* && "$WARPIPv6Status" == *不存在* ]]; then
yellow "IPV4与IPV6都为不存在，建议如下："
red "1、原来安装wgcf的，选择9切换到warp-go重装warp"
red "2、原来安装warp-go的，选择10切换到wgcf重装warp"
red "切记：如依旧如此，建议卸载并重启VPS，再重装方案一"
fi
}
S5menu(){
white "------------------------------------------------------------------------------------------------"
white " 方案二：当前 Socks5-WARP 官方客户端本地代理情况如下"
blue " ${S5Status}"
white "------------------------------------------------------------------------------------------------"
}

reswarp(){
unreswarp
crontab -l > /tmp/crontab.tmp
echo "0 4 * * * systemctl stop warp-go;systemctl restart warp-go;systemctl restart wg-quick@wgcf;systemctl restart warp-svc" >> /tmp/crontab.tmp
echo "@reboot screen -UdmS up /bin/bash /root/WARP-UP.sh" >> /tmp/crontab.tmp
echo "0 0 * * * rm -f /root/warpip/warp_log.txt" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}

unreswarp(){
crontab -l > /tmp/crontab.tmp
sed -i '/systemctl stop warp-go;systemctl restart warp-go;systemctl restart wg-quick@wgcf;systemctl restart warp-svc/d' /tmp/crontab.tmp
sed -i '/@reboot screen/d' /tmp/crontab.tmp
sed -i '/warp_log.txt/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp
rm /tmp/crontab.tmp
}

ONEWARPGO(){
if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
red "脚本不支持当前的 $op 系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
yellow "\n 请稍等，当前为warp-go核心安装模式，检测对端IP与出站情况……"
warpip

wgo1='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0#g" /usr/local/bin/warp.conf'
wgo2='sed -i "s#.*AllowedIPs.*#AllowedIPs = ::/0#g" /usr/local/bin/warp.conf'
wgo3='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0,::/0#g" /usr/local/bin/warp.conf'
wgo4='sed -i "/Endpoint6/d" /usr/local/bin/warp.conf && sed -i "/Endpoint/s/.*/Endpoint = '"$endpoint"'/" /usr/local/bin/warp.conf'
wgo5='sed -i "/Endpoint6/d" /usr/local/bin/warp.conf && sed -i "/Endpoint/s/.*/Endpoint = '"$endpoint"'/" /usr/local/bin/warp.conf'
wgo6='sed -i "/\[Script\]/a PostUp = ip -4 rule add from $(ip route get 162.159.192.1 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostDown = ip -4 rule delete from $(ip route get 162.159.192.1 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf'
wgo7='sed -i "/\[Script\]/a PostUp = ip -6 rule add from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostDown = ip -6 rule delete from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf'
wgo8='sed -i "/\[Script\]/a PostUp = ip -4 rule add from $(ip route get 162.159.192.1 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostDown = ip -4 rule delete from $(ip route get 162.159.192.1 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostUp = ip -6 rule add from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf && sed -i "/\[Script\]/a PostDown = ip -6 rule delete from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP "src \K\S+") lookup main\n" /usr/local/bin/warp.conf'

STOPwgcf(){
if [[ -n $(type -P warp-cli) ]]; then
red "已安装Socks5-WARP，不支持当前选择的WARP安装方案" 
systemctl restart warp-go && cf
fi
}

ShowWGCF(){
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
v4v6
warppflow=$((`grep -oP '"quota":\K\d+' <<< $(curl -sm4 "https://api.cloudflareclient.com/v0a884/reg/$(grep 'Device' /usr/local/bin/warp.conf 2>/dev/null | cut -d= -f2 | sed 's# ##g')" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $(grep 'Token' /usr/local/bin/warp.conf 2>/dev/null | cut -d= -f2 | sed 's# ##g')")`))
flow=`echo "scale=2; $warppflow/1000000000" | bc`
[[ -e /usr/local/bin/warpplus.log ]] && cfplus="WARP+账户(有限WARP+流量：$flow GB)，设备名称：$(sed -n 1p /usr/local/bin/warpplus.log)" || cfplus="WARP+Teams账户(无限WARP+流量)"
if [[ -n $v4 ]]; then
nf4
chatgpt4
checkgpt
gemini4
wgcfv4=$(curl -s4 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
get_ip_geo_info "$v4"
isp4="$geo_isp"
country="$geo_country"
case ${wgcfv4} in 
plus) 
WARPIPv4Status=$(white "WARP+状态：\c" ; rred "运行中，$cfplus" ; white " 服务商 Cloudflare 获取IPV4地址：\c" ; rred "$v4  $country" ; white " 奈飞NF解锁情况：\c" ; rred "$NF" ; white " ChatGPT解锁情况：\c" ; rred "$chat" ; white " Gemini解锁情况：\c" ; rred "$gemini");;  
on) 
WARPIPv4Status=$(white "WARP状态：\c" ; green "运行中，WARP普通账户(无限WARP流量)" ; white " 服务商 Cloudflare 获取IPV4地址：\c" ; green "$v4  $country" ; white " 奈飞NF解锁情况：\c" ; green "$NF" ; white " ChatGPT解锁情况：\c" ; green "$chat" ; white " Gemini解锁情况：\c" ; green "$gemini");;
off) 
WARPIPv4Status=$(white "WARP状态：\c" ; yellow "关闭中" ; white " 服务商 $isp4 获取IPV4地址：\c" ; yellow "$v4  $country" ; white " 奈飞NF解锁情况：\c" ; yellow "$NF" ; white " ChatGPT解锁情况：\c" ; yellow "$chat" ; white " Gemini解锁情况：\c" ; yellow "$gemini");; 
esac 
else
WARPIPv4Status=$(white "IPV4状态：\c" ; red "不存在IPV4地址 ")
fi 
if [[ -n $v6 ]]; then
nf6
chatgpt6
checkgpt
gemini6
wgcfv6=$(curl -s6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
get_ip_geo_info "$v6"
isp6="$geo_isp"
country="$geo_country"
case ${wgcfv6} in 
plus) 
WARPIPv6Status=$(white "WARP+状态：\c" ; rred "运行中，$cfplus" ; white " 服务商 Cloudflare 获取IPV6地址：\c" ; rred "$v6  $country" ; white " 奈飞NF解锁情况：\c" ; rred "$NF" ; white " ChatGPT解锁情况：\c" ; rred "$chat" ; white " Gemini解锁情况：\c" ; rred "$gemini");;  
on) 
WARPIPv6Status=$(white "WARP状态：\c" ; green "运行中，WARP普通账户(无限WARP流量)" ; white " 服务商 Cloudflare 获取IPV6地址：\c" ; green "$v6  $country" ; white " 奈飞NF解锁情况：\c" ; green "$NF" ; white " ChatGPT解锁情况：\c" ; green "$chat" ; white " Gemini解锁情况：\c" ; green "$gemini");;
off) 
WARPIPv6Status=$(white "WARP状态：\c" ; yellow "关闭中" ; white " 服务商 $isp6 获取IPV6地址：\c" ; yellow "$v6  $country" ; white " 奈飞NF解锁情况：\c" ; yellow "$NF" ; white " ChatGPT解锁情况：\c" ; yellow "$chat" ; white " Gemini解锁情况：\c" ; yellow "$gemini");;
esac 
else
WARPIPv6Status=$(white "IPV6状态：\c" ; red "不存在IPV6地址 ")
fi 
}

CheckWARP(){
i=0
while [ $i -le 9 ]; do let i++
yellow "共执行10次，第$i次获取warp的IP中……"
restwarpgo
checkwgcf
if [[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]]; then
green "恭喜！warp的IP获取成功！" && dns
break
else
red "遗憾！warp的IP获取失败"
fi
done
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
red "安装WARP失败，还原VPS，卸载WARP"
cwg
echo
[[ $release = Centos && ${vsid} -lt 7 ]] && yellow "当前系统版本号：Centos $vsid \n建议使用 Centos 7 以上系统 " 
[[ $release = Ubuntu && ${vsid} -lt 18 ]] && yellow "当前系统版本号：Ubuntu $vsid \n建议使用 Ubuntu 18 以上系统 " 
[[ $release = Debian && ${vsid} -lt 10 ]] && yellow "当前系统版本号：Debian $vsid \n建议使用 Debian 10 以上系统 "
yellow "提示："
red "你或许可以使用方案二或方案三来实现WARP"
red "也可以选择WGCF核心来安装WARP方案一"
exit
else 
green "ok" && systemctl restart warp-go
fi
}

nat4(){
[[ -n $(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+') ]] && wpgo4=$wgo6 || wpgo4=echo
}

WGCFv4(){
yellow "稍等3秒，检测VPS内warp环境"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps首次安装warp-go\n现添加WARP IPV4（IP出站表现：原生 IPV6 + WARP IPV4）" && sleep 2
wpgo1=$wgo1 && wpgo2=$wgo4 && wpgo3=$wgo8 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps首次安装warp-go\n现添加WARP IPV4（IP出站表现：原生 IPV6 + WARP IPV4）" && sleep 2
wpgo1=$wgo1 && wpgo2=$wgo5 && wpgo3=$wgo7 && nat4 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps首次安装warp-go\n现添加WARP IPV4（IP出站表现：仅WARP IPV4）" && sleep 2
wpgo1=$wgo1 && wpgo2=$wgo4 && wpgo3=$wgo6 && WGCFins
fi
echo 'w4' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
kill -15 $(pgrep warp-go) >/dev/null 2>&1
sleep 2 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps已安装warp-go\n现快速切换WARP IPV4（IP出站表现：原生 IPV6 + WARP IPV4）" && sleep 2
wpgo1=$wgo1 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps已安装warp-go\n现快速切换WARP IPV4（IP出站表现：原生 IPV6 + WARP IPV4）" && sleep 2
wpgo1=$wgo1 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps已安装warp-go\n现快速切换WARP IPV4（IP出站表现：仅WARP IPV4）" && sleep 2
wpgo1=$wgo1 && ABC
fi
echo 'w4' > /root/warpip/wp.log
cat /usr/local/bin/warp.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

WGCFv6(){
yellow "稍等3秒，检测VPS内warp环境"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps首次安装warp-go\n现添加WARP IPV6（IP出站表现：原生 IPV4 + WARP IPV6）" && sleep 2
wpgo1=$wgo2 && wpgo2=$wgo4 && wpgo3=$wgo8 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps首次安装warp-go\n现添加WARP IPV6（IP出站表现：仅WARP IPV6）" && sleep 2
wpgo1=$wgo2 && wpgo2=$wgo5 && wpgo3=$wgo7 && nat4 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps首次安装warp-go\n现添加WARP IPV6（IP出站表现：原生 IPV4 + WARP IPV6）" && sleep 2
wpgo1=$wgo2 && wpgo2=$wgo4 && wpgo3=$wgo6 && WGCFins
fi
echo 'w6' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
kill -15 $(pgrep warp-go) >/dev/null 2>&1
sleep 2 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps已安装warp-go\n现快速切换WARP IPV6（IP出站表现：原生 IPV4 + WARP IPV6）" && sleep 2
wpgo1=$wgo2 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps已安装warp-go\n现快速切换WARP IPV6（IP出站表现：仅WARP IPV6）" && sleep 2
wpgo1=$wgo2 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps已安装warp-go\n现快速切换WARP IPV6（IP出站表现：原生 IPV4 + WARP IPV6）" && sleep 2
wpgo1=$wgo2 && ABC
fi
echo 'w6' > /root/warpip/wp.log
cat /usr/local/bin/warp.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

WGCFv4v6(){
yellow "稍等3秒，检测VPS内warp环境"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps首次安装warp-go\n现添加WARP IPV4+IPV6（IP出站表现：WARP双栈 IPV4 + IPV6）" && sleep 2
wpgo1=$wgo3 && wpgo2=$wgo4 && wpgo3=$wgo8 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps首次安装warp-go\n现添加WARP IPV4+IPV6（IP出站表现：WARP双栈 IPV4 + IPV6）" && sleep 2
wpgo1=$wgo3 && wpgo2=$wgo5 && wpgo3=$wgo7 && nat4 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps首次安装warp-go\n现添加WARP IPV4+IPV6（IP出站表现：WARP双栈 IPV4 + IPV6）" && sleep 2
wpgo1=$wgo3 && wpgo2=$wgo4 && wpgo3=$wgo6 && WGCFins
fi
echo 'w64' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
kill -15 $(pgrep warp-go) >/dev/null 2>&1
sleep 2 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps已安装warp-go\n现快速切换WARP IPV4+IPV6（IP出站表现：WARP双栈 IPV4 + IPV6）" && sleep 2
wpgo1=$wgo3 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps已安装warp-go\n现快速切换WARP IPV4+IPV6（IP出站表现：WARP双栈 IPV4 + IPV6）" && sleep 2
wpgo1=$wgo3 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps已安装warp-go\n现快速切换WARP IPV4+IPV6（IP出站表现：WARP双栈 IPV4 + IPV6）" && sleep 2
wpgo1=$wgo3 && ABC
fi
echo 'w64' > /root/warpip/wp.log
cat /usr/local/bin/warp.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

ABC(){
echo $wpgo1 | sh
echo $wpgo2 | sh
echo $wpgo3 | sh
echo $wpgo4 | sh
}

dns(){
if [[ ! -f /etc/resolv.conf.bak ]]; then
mv /etc/resolv.conf /etc/resolv.conf.bak
rm -rf /etc/resolv.conf
cp -f /etc/resolv.conf.bak /etc/resolv.conf
chattr +i /etc/resolv.conf >/dev/null 2>&1
else
chattr +i /etc/resolv.conf >/dev/null 2>&1
fi
}

WGCFins(){
if [[ $release = Centos ]]; then
yum install epel-release -y;yum install iproute iputils -y
elif [[ $release = Debian ]]; then
apt install lsb-release -y
echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
apt update -y;apt install iproute2 openresolv dnsutils iputils-ping -y
elif [[ $release = Ubuntu ]]; then
apt update -y;apt install iproute2 openresolv dnsutils iputils-ping -y
fi
wget -N https://gitlab.com/rwkgyg/CFwarp/-/raw/main/warp-go_1.0.8_linux_${cpu} -O /usr/local/bin/warp-go && chmod +x /usr/local/bin/warp-go
yellow "正在申请WARP普通账户，请稍等！"
if [[ ! -s /usr/local/bin/warp.conf ]]; then
cpujg
curl -L -o warpapi -# --retry 2 https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/cpu1/$cpu
chmod +x warpapi
output=$(./warpapi)
private_key=$(echo "$output" | awk -F ': ' '/private_key/{print $2}')
device_id=$(echo "$output" | awk -F ': ' '/device_id/{print $2}')
warp_token=$(echo "$output" | awk -F ': ' '/token/{print $2}')
rm -rf warpapi
cat > /usr/local/bin/warp.conf <<EOF
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name = WARP
MTU  = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.192.1:2408
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive = 30
EOF
fi
chmod +x /usr/local/bin/warp.conf
sed -i '0,/AllowedIPs/{/AllowedIPs/d;}' /usr/local/bin/warp.conf
sed -i '/KeepAlive/a [Script]' /usr/local/bin/warp.conf
mtuwarp
sed -i "s/MTU.*/MTU = $MTU/g" /usr/local/bin/warp.conf
cat > /lib/systemd/system/warp-go.service << EOF
[Unit]
Description=warp-go service
After=network.target
Documentation=https://gitlab.com/ProjectWARP/warp-go
[Service]
WorkingDirectory=/root/
ExecStart=/usr/local/bin/warp-go --config=/usr/local/bin/warp.conf
Environment="LOG_LEVEL=verbose"
RemainAfterExit=yes
Restart=always
[Install]
WantedBy=multi-user.target
EOF
ABC
systemctl daemon-reload
systemctl enable warp-go
systemctl start warp-go
restwarpgo
cat /usr/local/bin/warp.conf && sleep 2
checkwgcf
if [[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]]; then
green "恭喜！warp的IP获取成功！" && dns
else
CheckWARP
fi
ShowWGCF && lncf && reswarp
curl -sL https://raw.githubusercontent.com/xxntmctx/warp-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /root/warpip/v
}

warpinscha(){
yellow "提示：VPS的本地出站IP将被你选择的warp的IP所接管，如VPS本地无该出站IP，则被另外生成warp的IP所接管"
echo
green "1. 安装/切换WARP单栈IPV4（回车默认）"
green "2. 安装/切换WARP单栈IPV6"
green "3. 安装/切换WARP双栈IPV4+IPV6"
readp "\n请选择：" wgcfwarp
if [ -z "${wgcfwarp}" ] || [ $wgcfwarp == "1" ];then
WGCFv4
elif [ $wgcfwarp == "2" ];then
WGCFv6
elif [ $wgcfwarp == "3" ];then
WGCFv4v6
else 
red "输入错误，请重新选择" && warpinscha
fi
echo
} 

WARPup(){
freewarp(){
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
v4v6
allowips=$(cat /usr/local/bin/warp.conf | grep AllowedIPs)
if [[ -n $v4 && -n $v6 ]]; then
endp=$wgo4
post=$wgo8
elif [[ -n $v6 && -z $v4 ]]; then
endp=$wgo5
[[ -n $(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+') ]] && post=$wgo8 || post=$wgo7
elif [[ -z $v6 && -n $v4 ]]; then
endp=$wgo4
post=$wgo6
fi
yellow "当前执行：申请WARP普通账户"
echo
yellow "正在申请WARP普通账户，请稍等！"
rm -rf /usr/local/bin/warp.conf /usr/local/bin/warp.conf.bak /usr/local/bin/warpplus.log
curl -Ls -o /usr/local/bin/warp.conf --retry 2 https://api.zeroteam.top/warp?format=warp-go
if [[ ! -s /usr/local/bin/warp.conf ]]; then
cpujg
curl -Ls -o warpapi --retry 2 https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/cpu1/$cpu
chmod +x warpapi
output=$(./warpapi)
private_key=$(echo "$output" | awk -F ': ' '/private_key/{print $2}')
device_id=$(echo "$output" | awk -F ': ' '/device_id/{print $2}')
warp_token=$(echo "$output" | awk -F ': ' '/token/{print $2}')
rm -rf warpapi
cat > /usr/local/bin/warp.conf <<EOF
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name = WARP
MTU  = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.192.1:2408
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive = 30
EOF
fi
chmod +x /usr/local/bin/warp.conf
sed -i '0,/AllowedIPs/{/AllowedIPs/d;}' /usr/local/bin/warp.conf
sed -i '/KeepAlive/a [Script]' /usr/local/bin/warp.conf
mtuwarp
sed -i "s/MTU.*/MTU = $MTU/g" /usr/local/bin/warp.conf
sed -i "s#.*AllowedIPs.*#$allowips#g" /usr/local/bin/warp.conf
echo $endp | sh
echo $post | sh
CheckWARP && ShowWGCF &&  WGCFmenu
}

green "1. WARP普通账户（无限流量）"
green "2. WARP+账户（有限流量）"
green "3. WARP Teams (Zero Trust)团队账户（无限流量）"
green "4. Socks5+WARP+账户（有限流量）"
readp "请选择想要切换的账户类型：" warpup
if [[ $warpup == 1 ]]; then
freewarp
fi

if [[ $warpup == 4 ]]; then
SOCKS5WARPUP
fi

if [[ $warpup == 2 ]]; then
[[ ! $(type -P warp-go) ]] && red "未安装warp-go" && exit
green "请复制手机WARP客户端WARP+状态下的按键许可证秘钥 或 网络分享的秘钥（26个字符），当前因为WARP-GO的BUG问题，大概率升级失败"
readp "请输入升级WARP+密钥：" ID
if [[ -z $ID ]]; then
red "未输入内容" && WARPup
fi
readp "设置设备名称，回车随机：" dname
if [[ -z $dname ]]; then
dname=`date +%s%N |md5sum | cut -c 1-4`
fi
green "设备名称为 $dname"
/usr/local/bin/warp-go --update --config=/usr/local/bin/warp.conf --license=$ID --device-name=$dname
i=0
while [ $i -le 9 ]; do let i++
yellow "共执行10次，第$i次升级WARP+账户中……" 
restwarpgo
checkwgcf
if [[ $wgcfv4 = plus || $wgcfv6 = plus ]]; then
rm -rf /usr/local/bin/warp.conf.bak /usr/local/bin/warpplus.log
echo "$dname" >> /usr/local/bin/warpplus.log && echo "$ID" >> /usr/local/bin/warpplus.log
green "WARP+ 账户升级成功！" && ShowWGCF && WGCFmenu && break
else
red "WARP+账户升级失败！" && sleep 1
fi
done
if [[ ! $wgcfv4 = plus && ! $wgcfv6 = plus ]]; then
green "建议如下："
yellow "1. 检查1.1.1.1 APP中的WARP+账户或网络分享的秘钥是否有流量"
yellow "2. 检查当前WARP许可证密钥绑定的设备超过5台，请进入手机端进行设备移除再尝试升级WARP+账户" && sleep 2
freewarp
fi
fi
    
if [[ $warpup == 3 ]]; then
[[ ! $(type -P warp-go) ]] && red "未安装warp-go" && exit
green "Zero Trust团队Token获取地址：https://web--public--warp-team-api--coia-mfs4.code.run/"
readp "请输入团队账户Token: " token
curl -Ls -o /usr/local/bin/warp.conf.bak --retry 2 https://api.zeroteam.top/warp?format=warp-go
if [[ ! -s /usr/local/bin/warp.conf.bak ]]; then
cpujg
curl -Ls -o warpapi --retry 2 https://gitlab.com/rwkgyg/CFwarp/-/raw/main/point/cpu1/$cpu
chmod +x warpapi
output=$(./warpapi)
private_key=$(echo "$output" | awk -F ': ' '/private_key/{print $2}')
device_id=$(echo "$output" | awk -F ': ' '/device_id/{print $2}')
warp_token=$(echo "$output" | awk -F ': ' '/token/{print $2}')
rm -rf warpapi
cat > /usr/local/bin/warp.conf.bak <<EOF
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name = WARP
MTU  = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.192.1:2408
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive = 30
EOF
fi
/usr/local/bin/warp-go --register --config=/usr/local/bin/warp.conf.bak --team-config=$token --device-name=vps+warp+teams+$(date +%s%N |md5sum | cut -c 1-3)
sed -i "2s#.*#$(sed -ne 2p /usr/local/bin/warp.conf.bak)#;3s#.*#$(sed -ne 3p /usr/local/bin/warp.conf.bak)#" /usr/local/bin/warp.conf >/dev/null 2>&1
sed -i "4s#.*#$(sed -ne 4p /usr/local/bin/warp.conf.bak)#;5s#.*#$(sed -ne 5p /usr/local/bin/warp.conf.bak)#" /usr/local/bin/warp.conf >/dev/null 2>&1
i=0
while [ $i -le 9 ]; do let i++
yellow "共执行10次，第$i次获取warp的IP中……"
restwarpgo
checkwgcf
if [[ $wgcfv4 = plus || $wgcfv6 = plus ]]; then
rm -rf /usr/local/bin/warp.conf.bak /usr/local/bin/warpplus.log
green "WARP Teams账户升级成功！" && ShowWGCF && WGCFmenu && break
else
red "WARP Teams账户升级失败！" && sleep 1
fi
done
if [[ ! $wgcfv4 = plus && ! $wgcfv6 = plus ]]; then
freewarp
fi
fi
}

WARPonoff(){
[[ ! $(type -P warp-go) ]] && red "WARP未安装，建议重新安装" && exit
readp "1. 关闭WARP功能（关闭WARP在线监测）\n2. 开启/重启WARP功能（启动WARP在线监测）\n0. 返回上一层\n 请选择：" unwp
if [ "$unwp" == "1" ]; then
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
systemctl disable warp-go
screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null
unreswarp
checkwgcf 
[[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]] && green "关闭WARP成功" || red "关闭WARP失败"
elif [ "$unwp" == "2" ]; then
CheckWARP
xyz
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
[[ $name =~ "up" ]] && green "WARP在线监测启动成功" || red "WARP在线监测启动失败，查看screen是否安装成功"
reswarp
checkwgcf 
[[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]] && green "开启warp成功" || red "开启warp失败"
else
cf
fi
}

cwg(){
screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null
systemctl disable warp-go >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 
chattr -i /etc/resolv.conf >/dev/null 2>&1
sed -i '/^precedence ::ffff:0:0\/96  100/d' /etc/gai.conf 2>/dev/null
rm -rf /usr/local/bin/warp-go /usr/local/bin/warpplus.log /usr/local/bin/warp.conf /usr/local/bin/wgwarp.conf /usr/local/bin/sbwarp.json /usr/bin/warp-go /lib/systemd/system/warp-go.service /root/WARP-UP.sh
rm -rf /root/warpip
}

changewarp(){
cwg && ONEWGCFWARP
}

upwarpgo(){
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
wget -N https://gitlab.com/rwkgyg/CFwarp/-/raw/main/warp-go_1.0.8_linux_${cpu} -O /usr/local/bin/warp-go && chmod +x /usr/local/bin/warp-go
restwarpgo
loVERSION="$(/usr/local/bin/warp-go -v | sed -n 1p | awk '{print $1}' | awk -F"/" '{print $NF}')"
green " 当前 WARP-GO 已安装内核版本号：${loVERSION} ，已是最新版本"
}

start_menu(){
ShowWGCF;ShowSOCKS5
clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
echo
white "xxntmctx Github项目  ：github.com/xxntmctx (Forked from yonggekkk)"
white "甬哥Blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
yellow " 任意选择适合自己的warp现实方案（选项1、2、3，可单选，可多选共存）"
yellow " 进入脚本快捷方式：cf"
white " ================================================================="
green "  1. 方案一：安装/切换WARP-GO"
green "  2. 方案二：安装Socks5-WARP"
green "  3. 方案三：生成WARP-Wireguard配置文件、二维码"
green "  4. 卸载WARP"
white " -----------------------------------------------------------------"
green "  5. 关闭、开启/重启WARP"
green "  6. WARP其他选项"
green "  7. WARP三类账户升级/切换"
green "  8. 更新CFwarp安装脚本"
green "  9. 更新WARP-GO内核"
green " 10. 将当前WARP-GO内核替换为WGCF-WARP内核"
green "  0. 退出脚本 "
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
cfwarpshow
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white " VPS系统信息如下："
white " 操作系统: $(blue "$op") \c" && white " 内核版本: $(blue "$version") \c" && white " CPU架构 : $(blue "$cpu") \c" && white " 虚拟化类型: $(blue "$vi")"
WGCFmenu
S5menu
echo
readp " 请输入数字:" Input
case "$Input" in     
 1 ) warpinscha;;
 2 ) SOCKS5ins;;
 3 ) WGproxy;;
 4 ) WARPun;;
 5 ) WARPonoff;;
 6 ) WARPtools;;
 7 ) WARPup;;
 8 ) UPwpyg;;
 9 ) upwarpgo;;
 10 ) changewarp;;
 * ) exit
esac
}
if [ $# == 0 ]; then
bit=`uname -m`
[[ $bit = aarch64 ]] && cpu=arm64
if [[ $bit = x86_64 ]]; then
amdv=$(cat /proc/cpuinfo | grep flags | head -n 1 | cut -d: -f2)
case "$amdv" in
*avx512*) cpu=amd64v4;;
*avx2*) cpu=amd64v3;;
*sse3*) cpu=amd64v2;;
*) cpu=amd64;;
esac
fi
start_menu
fi
}

ONEWGCFWARP(){
if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
red "脚本不支持当前的 $op 系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
yellow "\n 请稍等，当前为wgcf核心安装模式，检测对端IP与出站情况……"
warpip

ud4='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 162.159.192.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 162.159.192.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
ud6='sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
ud4ud6='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 162.159.192.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 162.159.192.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:d0::a29f:c001 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
c1="sed -i '/0\.0\.0\.0\/0/d' /etc/wireguard/wgcf.conf"
c2="sed -i '/\:\:\/0/d' /etc/wireguard/wgcf.conf"
c3="sed -i "s/engage.cloudflareclient.com:2408/$endpoint/g" /etc/wireguard/wgcf.conf"
c4="sed -i "s/engage.cloudflareclient.com:2408/$endpoint/g" /etc/wireguard/wgcf.conf"
c5="sed -i 's/1.1.1.1/1.1.1.1,8.8.8.8,8.8.4.4,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844/g' /etc/wireguard/wgcf.conf"
c6="sed -i 's/1.1.1.1/2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,8.8.8.8,8.8.4.4/g' /etc/wireguard/wgcf.conf"

ShowWGCF(){
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
v4v6
warppflow=$((`grep -oP '"quota":\K\d+' <<< $(curl -sm4 "https://api.cloudflareclient.com/v0a884/reg/$(grep 'device_id' /etc/wireguard/wgcf-account.toml 2>/dev/null | cut -d \' -f2)" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $(grep 'access_token' /etc/wireguard/wgcf-account.toml 2>/dev/null | cut -d \' -f2)")`))
flow=`echo "scale=2; $warppflow/1000000000" | bc`
[[ -e /etc/wireguard/wgcf+p.log ]] && cfplus="WARP+账户(有限WARP+流量：$flow GB)，设备名称：$(grep -s 'Device name' /etc/wireguard/wgcf+p.log | awk '{ print $NF }')" || cfplus="WARP+Teams账户(无限WARP+流量)"
if [[ -n $v4 ]]; then
nf4
chatgpt4
checkgpt
gemini4
wgcfv4=$(curl -s4 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
get_ip_geo_info "$v4"
isp4="$geo_isp"
country="$geo_country"
case ${wgcfv4} in 
plus) 
WARPIPv4Status=$(white "WARP+状态：\c" ; rred "运行中，$cfplus" ; white " 服务商 Cloudflare 获取IPV4地址：\c" ; rred "$v4  $country" ; white " 奈飞NF解锁情况：\c" ; rred "$NF" ; white " ChatGPT解锁情况：\c" ; rred "$chat" ; white " Gemini解锁情况：\c" ; rred "$gemini");;  
on) 
WARPIPv4Status=$(white "WARP状态：\c" ; green "运行中，WARP普通账户(无限WARP流量)" ; white " 服务商 Cloudflare 获取IPV4地址：\c" ; green "$v4  $country" ; white " 奈飞NF解锁情况：\c" ; green "$NF" ; white " ChatGPT解锁情况：\c" ; green "$chat" ; white " Gemini解锁情况：\c" ; green "$gemini");;
off) 
WARPIPv4Status=$(white "WARP状态：\c" ; yellow "关闭中" ; white " 服务商 $isp4 获取IPV4地址：\c" ; yellow "$v4  $country" ; white " 奈飞NF解锁情况：\c" ; yellow "$NF" ; white " ChatGPT解锁情况：\c" ; yellow "$chat" ; white " Gemini解锁情况：\c" ; yellow "$gemini");; 
esac 
else
WARPIPv4Status=$(white "IPV4状态：\c" ; red "不存在IPV4地址 ")
fi 
if [[ -n $v6 ]]; then
nf6
chatgpt6
checkgpt
gemini6
wgcfv6=$(curl -s6 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2) 
get_ip_geo_info "$v6"
isp6="$geo_isp"
country="$geo_country"
case ${wgcfv6} in 
plus) 
WARPIPv6Status=$(white "WARP+状态：\c" ; rred "运行中，$cfplus" ; white " 服务商 Cloudflare 获取IPV6地址：\c" ; rred "$v6  $country" ; white " 奈飞NF解锁情况：\c" ; rred "$NF" ; white " ChatGPT解锁情况：\c" ; rred "$chat" ; white " Gemini解锁情况：\c" ; rred "$gemini");;  
on) 
WARPIPv6Status=$(white "WARP状态：\c" ; green "运行中，WARP普通账户(无限WARP流量)" ; white " 服务商 Cloudflare 获取IPV6地址：\c" ; green "$v6  $country" ; white " 奈飞NF解锁情况：\c" ; green "$NF" ; white " ChatGPT解锁情况：\c" ; green "$chat" ; white " Gemini解锁情况：\c" ; green "$gemini");;
off) 
WARPIPv6Status=$(white "WARP状态：\c" ; yellow "关闭中" ; white " 服务商 $isp6 获取IPV6地址：\c" ; yellow "$v6  $country" ; white " 奈飞NF解锁情况：\c" ; yellow "$NF" ; white " ChatGPT解锁情况：\c" ; yellow "$chat" ; white " Gemini解锁情况：\c" ; yellow "$gemini");;
esac 
else
WARPIPv6Status=$(white "IPV6状态：\c" ; red "不存在IPV6地址 ")
fi 
}

STOPwgcf(){
if [[ $(type -P warp-cli) ]]; then
red "已安装Socks5-WARP，不支持当前选择的wgcf-warp安装方案" 
systemctl restart wg-quick@wgcf && cf
fi
}

fawgcf(){
rm -f /etc/wireguard/wgcf+p.log
ID=$(cat /etc/wireguard/buckup-account.toml | grep license_key | awk '{print $3}')
sed -i "s/license_key.*/license_key = $ID/g" /etc/wireguard/wgcf-account.toml
cd /etc/wireguard && wgcf update >/dev/null 2>&1
wgcf generate >/dev/null 2>&1 && cd
sed -i "2s#.*#$(sed -ne 2p /etc/wireguard/wgcf-profile.conf)#;4s#.*#$(sed -ne 4p /etc/wireguard/wgcf-profile.conf)#" /etc/wireguard/wgcf.conf
CheckWARP && ShowWGCF &&  WGCFmenu
}

ABC(){
echo $ABC1 | sh
echo $ABC2 | sh
echo $ABC3 | sh
echo $ABC4 | sh
echo $ABC5 | sh
}

conf(){
rm -rf /etc/wireguard/wgcf.conf
cp -f /etc/wireguard/buckup-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1
cp -f /etc/wireguard/wgcf-profile.conf /etc/wireguard/buckup-profile.conf >/dev/null 2>&1
}

nat4(){
[[ -n $(ip route get 162.159.192.1 2>/dev/null | grep -oP 'src \K\S+') ]] && ABC4=$ud4 || ABC4=echo
}

WGCFv4(){
yellow "稍等3秒，检测VPS内warp环境"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps首次安装wgcf-warp\n现添加IPV4单栈wgcf-warp模式" && sleep 2
ABC1=$c5 && ABC2=$c2 && ABC3=$ud4 && ABC4=$c3 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps首次安装wgcf-warp\n现添加IPV4单栈wgcf-warp模式" && sleep 2
ABC1=$c5 && ABC2=$c4 && ABC3=$c2 && nat4 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps首次安装wgcf-warp\n现添加IPV4单栈wgcf-warp模式" && sleep 2
ABC1=$c5 && ABC2=$c2 && ABC3=$c3 && ABC4=$ud4 && WGCFins
fi
echo 'w4' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
wg-quick down wgcf >/dev/null 2>&1
sleep 1 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps已安装wgcf-warp\n现快速切换IPV4单栈wgcf-warp模式" && sleep 2
conf && ABC1=$c5 && ABC2=$c2 && ABC3=$ud4 && ABC4=$c3 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps已安装wgcf-warp\n现快速切换IPV4单栈wgcf-warp模式" && sleep 2
conf && ABC1=$c5 && ABC2=$c4 && ABC3=$c2 && nat4 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps已安装wgcf-warp\n现快速切换IPV4单栈wgcf-warp模式" && sleep 2
conf && ABC1=$c5 && ABC2=$c2 && ABC3=$c3 && ABC4=$ud4 && ABC
fi
echo 'w4' > /root/warpip/wp.log
cat /etc/wireguard/wgcf.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

WGCFv6(){
yellow "稍等3秒，检测VPS内warp环境"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps首次安装wgcf-warp\n现添加IPV6单栈wgcf-warp模式" && sleep 2
ABC1=$c5 && ABC2=$c1 && ABC3=$ud6 && ABC4=$c3 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps首次安装wgcf-warp\n现添加IPV6单栈wgcf-warp模式(无IPV4！！！)" && sleep 2
ABC1=$c6 && ABC2=$c1 && ABC3=$c4 && nat4 && ABC5=$ud6 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps首次安装wgcf-warp\n现添加IPV6单栈wgcf-warp模式" && sleep 2
ABC1=$c5 && ABC2=$c3 && ABC3=$c1 && WGCFins
fi
echo 'w6' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
wg-quick down wgcf >/dev/null 2>&1
sleep 1 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps已安装wgcf-warp\n现快速切换IPV6单栈wgcf-warp模式" && sleep 2
conf && ABC1=$c5 && ABC2=$c1 && ABC3=$ud6 && ABC4=$c3 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps已安装wgcf-warp\n现快速切换IPV6单栈wgcf-warp模式(无IPV4！！！)" && sleep 2
conf && ABC1=$c6 && ABC2=$c1 && ABC3=$c4 && nat4 && ABC5=$ud6 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps已安装wgcf-warp\n现快速切换IPV6单栈wgcf-warp模式" && sleep 2
conf && ABC1=$c5 && ABC2=$c3 && ABC3=$c1 && ABC
fi
echo 'w6' > /root/warpip/wp.log
cat /etc/wireguard/wgcf.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

WGCFv4v6(){
yellow "稍等3秒，检测VPS内warp环境"
docker && checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps首次安装wgcf-warp\n现添加IPV4+IPV6双栈wgcf-warp模式" && sleep 2
ABC1=$c5 && ABC2=$ud4ud6 && ABC3=$c3 && WGCFins
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps首次安装wgcf-warp\n现添加IPV4+IPV6双栈wgcf-warp模式" && sleep 2
ABC1=$c5 && ABC2=$c4 && ABC3=$ud6 && nat4 && WGCFins
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps首次安装wgcf-warp\n现添加IPV4+IPV6双栈wgcf-warp模式" && sleep 2
ABC1=$c5 && ABC2=$c3 && ABC3=$ud4 && WGCFins
fi
echo 'w64' > /root/warpip/wp.log && xyz && WGCFmenu
first4
else
wg-quick down wgcf >/dev/null 2>&1
sleep 1 && v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "当前原生v4+v6双栈vps已安装wgcf-warp\n现快速切换IPV4+IPV6双栈wgcf-warp模式" && sleep 2
conf && ABC1=$c5 && ABC2=$ud4ud6 && ABC3=$c3 && ABC
fi
if [[ -n $v6 && -z $v4 ]]; then
green "当前原生v6单栈vps已安装wgcf-warp\n现快速切换IPV4+IPV6双栈wgcf-warp模式" && sleep 2
conf && ABC1=$c5 && ABC2=$c4 && ABC3=$ud6 && nat4 && ABC
fi
if [[ -z $v6 && -n $v4 ]]; then
green "当前原生v4单栈vps已安装wgcf-warp\n现快速切换IPV4+IPV6双栈wgcf-warp模式" && sleep 2
conf && ABC1=$c5 && ABC2=$c3 && ABC3=$ud4 && ABC
fi
echo 'w64' > /root/warpip/wp.log
cat /etc/wireguard/wgcf.conf && sleep 2
CheckWARP && first4 && ShowWGCF && WGCFmenu
fi
}

CheckWARP(){
i=0
wg-quick down wgcf >/dev/null 2>&1
while [ $i -le 9 ]; do let i++
yellow "共执行10次，第$i次获取warp的IP中……"
systemctl restart wg-quick@wgcf >/dev/null 2>&1
checkwgcf
[[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]] && green "恭喜！warp的IP获取成功！" && break || red "遗憾！warp的IP获取失败"
done
checkwgcf
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
red "安装WARP失败，还原VPS，卸载Wgcf-WARP组件中……"
cwg
echo
[[ $release = Centos && ${vsid} -lt 7 ]] && yellow "当前系统版本号：Centos $vsid \n建议使用 Centos 7 以上系统 " 
[[ $release = Ubuntu && ${vsid} -lt 18 ]] && yellow "当前系统版本号：Ubuntu $vsid \n建议使用 Ubuntu 18 以上系统 " 
[[ $release = Debian && ${vsid} -lt 10 ]] && yellow "当前系统版本号：Debian $vsid \n建议使用 Debian 10 以上系统 "
yellow "提示："
red "你或许可以使用方案二或方案三来实现WARP"
red "也可以选择WARP-GO核心来安装WARP方案一"
exit
else 
green "ok"
fi
}

WGCFins(){
rm -rf /usr/local/bin/wgcf /etc/wireguard/wgcf.conf /etc/wireguard/wgcf-profile.conf /etc/wireguard/wgcf-account.toml /etc/wireguard/wgcf+p.log /etc/wireguard/ID /usr/bin/wireguard-go /usr/bin/wgcf wgcf-account.toml wgcf-profile.conf /etc/wireguard/buckup-profile.conf
if [[ $release = Centos ]]; then
yum install epel-release -y;yum install iproute iptables wireguard-tools -y
elif [[ $release = Debian ]]; then
apt install lsb-release -y
echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
apt update -y;apt install iproute2 openresolv dnsutils iptables iputils-ping -y;apt install wireguard-tools --no-install-recommends -y      		
elif [[ $release = Ubuntu ]]; then
apt update -y;apt install iproute2 openresolv dnsutils iptables iputils-ping -y;apt install wireguard-tools --no-install-recommends -y			
fi
wget -N https://gitlab.com/rwkgyg/cfwarp/raw/main/wgcf_2.2.22_$cpu -O /usr/local/bin/wgcf && chmod +x /usr/local/bin/wgcf         
if [[ $main -lt 5 || $minor -lt 6 ]] || [[ $vi =~ lxc|openvz ]]; then
[[ -e /usr/bin/wireguard-go ]] || wget -N https://gitlab.com/rwkgyg/cfwarp/raw/main/wireguard-go -O /usr/bin/wireguard-go && chmod +x /usr/bin/wireguard-go
fi
echo | wgcf register
until [[ -e wgcf-account.toml ]]
do
yellow "申请warp普通账户过程中可能会多次提示：429 Too Many Requests，请等待30秒" && sleep 1
echo | wgcf register --accept-tos
done
wgcf generate
mtuwarp

#blue "检测能否自动生成并使用warp+账户，请稍等10秒"
#wppluskey >/dev/null 2>&1
sed -i "s/MTU.*/MTU = $MTU/g" wgcf-profile.conf
cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1
cp -f wgcf-account.toml /etc/wireguard/buckup-account.toml  >/dev/null 2>&1
cp -f wgcf-profile.conf /etc/wireguard/buckup-profile.conf  >/dev/null 2>&1
ABC
mv -f wgcf-profile.conf /etc/wireguard >/dev/null 2>&1
mv -f wgcf-account.toml /etc/wireguard >/dev/null 2>&1
#ID=$(tail -n1 /root/WARP+Keys.txt | cut -d' ' -f1 2>/dev/null)
#if [[ -n $ID ]]; then
#green "使用warp+密钥"
#green "$(tail -n1 /root/WARP+Keys.txt | cut -d' ' -f1 2>/dev/null)"
#sed -i "s/license_key.*/license_key = '$ID'/g" /etc/wireguard/wgcf-account.toml
#sbmc=warp+$(date +%s%N |md5sum | cut -c 1-3)
#SBID="--name $(echo $sbmc | sed s/[[:space:]]/_/g)"
#rm -rf warpplus.sh
#cd /etc/wireguard && wgcf update $SBID > /etc/wireguard/wgcf+p.log 2>&1
#wgcf generate && cd
#sed -i "2s#.*#$(sed -ne 2p /etc/wireguard/wgcf-profile.conf)#;4s#.*#$(sed -ne 4p /etc/wireguard/wgcf-profile.conf)#" /etc/wireguard/wgcf.conf
#sed -i "2s#.*#$(sed -ne 2p /etc/wireguard/wgcf-profile.conf)#;4s#.*#$(sed -ne 4p /etc/wireguard/wgcf-profile.conf)#" /etc/wireguard/buckup-profile.conf
#else
#yellow "warp+无法自动生成，直接生成warp普通账户"
#fi
systemctl enable wg-quick@wgcf
cat /etc/wireguard/wgcf.conf && sleep 2
CheckWARP && ShowWGCF && lncf && reswarp
curl -sL https://raw.githubusercontent.com/xxntmctx/warp-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /root/warpip/v
}

WARPup(){
backconf(){
red "升级失败，自动恢复warp普通账户"
sed -i "2s#.*#$(sed -ne 2p /etc/wireguard/wgcf-profile.conf)#;4s#.*#$(sed -ne 4p /etc/wireguard/wgcf-profile.conf)#" /etc/wireguard/wgcf.conf
CheckWARP && ShowWGCF && WGCFmenu
}
readp "1.Teams团队账户\n2.warp+账户\n3.普通warp账户\n4.Socks5+WARP+账户\n0.返回上一层\n 请选择：" cd
case "$cd" in 
1 )
result(){
sed -i "s#PrivateKey.*#PrivateKey = $PRIVATEKEY#g;s#Address.*128#Address = $ADDRESS6/128#g" /etc/wireguard/wgcf.conf
sed -i "s#PrivateKey.*#PrivateKey = $PRIVATEKEY#g;s#Address.*128#Address = $ADDRESS6/128#g" /etc/wireguard/buckup-profile.conf
CheckWARP
checkwgcf
if [[ $wgcfv4 = plus || $wgcfv6 = plus ]]; then
rm -rf /etc/wireguard/wgcf+p.log && green "wgcf-warp+Teams账户已生效" && ShowWGCF && WGCFmenu
else
backconf
fi
}
[[ ! $(type -P wg-quick) ]] && red "未安装wgcf-warp，安装好wgcf-warp才能执行" && exit
green "1. 使用Token获取Teams团队账户，Token获取地址：https://web--public--warp-team-api--coia-mfs4.code.run/"
green "2. 手动复制私钥与IPV6地址"
green "0. 退出"
readp "请选择：" up
if [[ $up == 1 ]]; then
readp " 请复制团队账户Token： " TEAM_TOKEN
PRIVATEKEY=$(wg genkey)
PUBLICKEY=$(wg pubkey <<< "$PRIVATEKEY")
INSTALL_ID=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22)
FCM_TOKEN="${INSTALL_ID}:APA91b$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 134)"
ERROR_TIMES=0
while [ "$ERROR_TIMES" -le 3 ]; do
(( ERROR_TIMES++ ))
if [[ "$TEAMS" =~ 'token is expired' ]]; then
read -p " 请刷新token重新复制 " TEAM_TOKEN
elif [[ "$TEAMS" =~ 'error' ]]; then
read -p " 请刷新token重新复制 " TEAM_TOKEN
elif [[ "$TEAMS" =~ 'organization' ]]; then
break
fi
TEAMS=$(curl --silent --location --tlsv1.3 --request POST 'https://api.cloudflareclient.com/v0a2158/reg' \
--header 'User-Agent: okhttp/3.12.1' \
--header 'CF-Client-Version: a-6.10-2158' \
--header 'Content-Type: application/json' \
--header "Cf-Access-Jwt-Assertion: ${TEAM_TOKEN}" \
--data '{"key":"'${PUBLICKEY}'","install_id":"'${INSTALL_ID}'","fcm_token":"'${FCM_TOKEN}'","tos":"'$(date +"%Y-%m-%dT%H:%M:%S.%3NZ")'","model":"Linux","serial_number":"'${INSTALL_ID}'","locale":"zh_CN"}')
ADDRESS6=$(expr "$TEAMS" : '.*"v6":[ ]*"\([^"]*\).*')
done
result
elif [[ $up == 2 ]]; then
readp "请复制privateKey(44个字符）：" PRIVATEKEY
readp "请复制IPV6的Address：" ADDRESS6
result
else
exit
fi
;;
2 )
result(){
sed -i "s#PrivateKey.*#PrivateKey = $PRIVATEKEY#g;s#Address.*128#Address = $ADDRESS6/128#g" /etc/wireguard/wgcf.conf
sed -i "s#PrivateKey.*#PrivateKey = $PRIVATEKEY#g;s#Address.*128#Address = $ADDRESS6/128#g" /etc/wireguard/buckup-profile.conf
CheckWARP
checkwgcf
if [[ $wgcfv4 = plus || $wgcfv6 = plus ]]; then
echo "未知" > /etc/wireguard/wgcf+p.log && green "wgcf-warp+账户已生效" && ShowWGCF && WGCFmenu
else
fawgcf
fi
}
[[ ! $(type -P wg-quick) ]] && red "未安装wgcf-warp，安装好wgcf-warp才能执行" && exit
green "1. 输入密钥方式"
green "2. 手动复制私钥与IPV6地址"
green "0. 退出"
readp "请选择：" up
if [[ $up == 1 ]]; then
readp "请复制手机WARP客户端WARP+状态下的按键许可证秘钥 或 网络分享的秘钥（26个字符）:" ID
[[ -n $ID ]] && sed -i "s/license_key.*/license_key = '$ID'/g" /etc/wireguard/wgcf-account.toml && readp "设备名称重命名(直接回车随机命名)：" sbmc || (red "未输入按键许可证秘钥(26个字符)" && cf)
[[ -n $sbmc ]] && SBID="--name $(echo $sbmc | sed s/[[:space:]]/_/g)"
cd /etc/wireguard && wgcf update $SBID > /etc/wireguard/wgcf+p.log 2>&1
wgcf generate && cd
sed -i "2s#.*#$(sed -ne 2p /etc/wireguard/wgcf-profile.conf)#;4s#.*#$(sed -ne 4p /etc/wireguard/wgcf-profile.conf)#" /etc/wireguard/wgcf.conf
sed -i "2s#.*#$(sed -ne 2p /etc/wireguard/wgcf-profile.conf)#;4s#.*#$(sed -ne 4p /etc/wireguard/wgcf-profile.conf)#" /etc/wireguard/buckup-profile.conf
CheckWARP && checkwgcf
if [[ $wgcfv4 = plus || $wgcfv6 = plus ]]; then
warppflow=$((`grep -oP '"quota":\K\d+' <<< $(curl -s "https://api.cloudflareclient.com/v0a884/reg/$(grep 'device_id' /etc/wireguard/wgcf-account.toml 2>/dev/null | cut -d \' -f2)" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $(grep 'access_token' /etc/wireguard/wgcf-account.toml 2>/dev/null | cut -d \' -f2)")`))
flow=`echo "scale=2; $warppflow/1000000000" | bc`
green "已升级为wgcf-warp+账户\nwgcf-warp+账户设备名称：$(grep -s 'Device name' /etc/wireguard/wgcf+p.log | awk '{ print $NF }')\nwgcf-warp+账户剩余流量：$flow GB"
ShowWGCF && WGCFmenu 
else
red "经IP检测，升级warp+失败，请确保密钥使用的设备不超过5个，建议更换下秘钥再尝试，脚本退出" && exit
fi
elif [[ $up == 2 ]]; then
readp "请复制privateKey(44个字符）：" PRIVATEKEY
readp "请复制IPV6的Address：" ADDRESS6
result
else
exit
fi
;;
3 )
checkwgcf
if [[ $wgcfv4 = plus || $wgcfv6 = plus ]]; then
fawgcf
else
yellow "当前已是wgcf-warp普通账号"
ShowWGCF && WGCFmenu
fi;;
4 )
SOCKS5WARPUP;;
0 ) cf
esac
}

WARPonoff(){
[[ ! $(type -P wg-quick) ]] && red "WARP未安装，建议重新安装" && exit
readp "1. 关闭WARP功能（关闭WARP在线监测）\n2. 开启/重启WARP功能（启动WARP在线监测）\n0. 返回上一层\n 请选择：" unwp
if [ "$unwp" == "1" ]; then
wg-quick down wgcf >/dev/null 2>&1
systemctl stop wg-quick@wgcf >/dev/null 2>&1
systemctl disable wg-quick@wgcf >/dev/null 2>&1
screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null
unreswarp
checkwgcf 
[[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]] && green "关闭warp成功" || red "关闭warp失败"
elif [ "$unwp" == "2" ]; then
wg-quick down wgcf >/dev/null 2>&1
systemctl restart wg-quick@wgcf >/dev/null 2>&1
xyz
name=`screen -ls | grep '(Detached)' | awk '{print $1}' | awk -F "." '{print $2}'`
[[ $name =~ "up" ]] && green "WARP在线监测启动成功" || red "WARP在线监测启动失败，查看screen是否安装成功"
reswarp
checkwgcf 
[[ $wgcfv4 =~ on|plus || $wgcfv6 =~ on|plus ]] && green "开启warp成功" || red "开启warp失败"
else
cf
fi
}

cwg(){
screen -ls | awk '/\.up/ {print $1}' | cut -d "." -f 1 | xargs kill 2>/dev/null
wg-quick down wgcf >/dev/null 2>&1
systemctl disable wg-quick@wgcf >/dev/null 2>&1
$yumapt remove wireguard-tools
$yumapt autoremove
dig9
sed -i '/^precedence ::ffff:0:0\/96  100/d' /etc/gai.conf 2>/dev/null
rm -rf /usr/local/bin/wgcf /usr/bin/wg-quick /etc/wireguard/wgcf.conf /etc/wireguard/wgcf-profile.conf /etc/wireguard/buckup-account.toml /etc/wireguard/wgcf-account.toml /etc/wireguard/wgcf+p.log /etc/wireguard/ID /usr/bin/wireguard-go /usr/bin/wgcf wgcf-account.toml wgcf-profile.conf /etc/wireguard/buckup-profile.conf /root/WARP-UP.sh
rm -rf /root/warpip /root/WARP+Keys.txt
}

warpinscha(){
yellow "提示：VPS的本地出站IP将被你选择的warp的IP所接管，如VPS本地无该出站IP，则被另外生成warp的IP所接管"
echo
green "1. 安装/切换wgcf-warp单栈IPV4（回车默认）"
green "2. 安装/切换wgcf-warp单栈IPV6"
green "3. 安装/切换wgcf-warp双栈IPV4+IPV6"
readp "\n请选择：" wgcfwarp
if [ -z "${wgcfwarp}" ] || [ $wgcfwarp == "1" ];then
WGCFv4
elif [ $wgcfwarp == "2" ];then
WGCFv6
elif [ $wgcfwarp == "3" ];then
WGCFv4v6
else 
red "输入错误，请重新选择" && warpinscha
fi
echo
}  

changewarp(){
cwg && ONEWARPGO
}

start_menu(){
ShowWGCF;ShowSOCKS5
clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
echo
white "xxntmctx Github项目  ：github.com/xxntmctx (Forked from yonggekkk)"
white "甬哥Blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
yellow " 任意选择适合自己的warp现实方案（选项1、2、3，可单选，可多选共存）"
yellow " 进入脚本快捷方式：cf"
white " ================================================================="
green "  1. 方案一：安装/切换WGCF-WARP"
green "  2. 方案二：安装Socks5-WARP"
green "  3. 方案三：生成WARP-Wireguard配置文件、二维码"
green "  4. 卸载WARP"
white " -----------------------------------------------------------------"
green "  5. 关闭、开启/重启WARP"
green "  6. WARP其他选项"
green "  7. WARP三类账户升级/切换"
green "  8. 更新CFwarp安装脚本" 
green "  9. 将当前WGCF-WARP内核替换为WARP-GO内核"
green "  0. 退出脚本 "
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
cfwarpshow
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
white " VPS系统信息如下："
white " 操作系统: $(blue "$op") \c" && white " 内核版本: $(blue "$version") \c" && white " CPU架构 : $(blue "$cpu") \c" && white " 虚拟化类型: $(blue "$vi")"
WGCFmenu
S5menu
echo
readp " 请输入数字:" Input
case "$Input" in     
 1 ) warpinscha;;
 2 ) [[ $cpu = amd64 ]] && SOCKS5ins || exit;;
 3 ) WGproxy;;
 4 ) WARPun;;
 5 ) WARPonoff;;
 6 ) WARPtools;;
 7 ) WARPup;;
 8 ) UPwpyg;;
 9 ) changewarp;;
 * ) exit 
esac
}

if [ $# == 0 ]; then
cpujg
start_menu
fi
}

checkyl(){
if [ ! -f warp_update ]; then
green "首次运行CFwarp-yg脚本，安装必要的依赖……请稍等"
if [[ $release = Centos && ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
cd
fi
if [ -x "$(command -v apt-get)" ]; then
apt update -y && apt install curl wget -y
elif [ -x "$(command -v yum)" ]; then
yum update && yum install epel-release -y && yum install curl wget -y
elif [ -x "$(command -v dnf)" ]; then
dnf update -y && dnf install curl wget -y
fi
if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
if ! command -v "cronie" &> /dev/null; then
if [ -x "$(command -v yum)" ]; then
yum install -y cronie
elif [ -x "$(command -v dnf)" ]; then
dnf install -y cronie
fi
fi
fi
touch warp_update
tun
fi
}

warpyl(){
packages=("curl" "openssl" "bc" "python3" "screen" "qrencode" "wget")
inspackages=("curl" "openssl" "bc" "python3" "screen" "qrencode" "wget")
for i in "${!packages[@]}"; do
package="${packages[$i]}"
inspackage="${inspackages[$i]}"
if ! command -v "$package" &> /dev/null; then
if [ -x "$(command -v apt-get)" ]; then
apt-get install -y "$inspackage"
elif [ -x "$(command -v yum)" ]; then
yum install -y "$inspackage"
elif [ -x "$(command -v dnf)" ]; then
dnf install -y "$inspackage"
fi
fi
done
}

startCFwarp(){
checkyl
clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
echo
white "xxntmctx Github项目  ：github.com/xxntmctx (Forked from yonggekkk)"
white "甬哥Blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
yellow "请稍等5秒，检测 Netflix 与 ChatGPT 解锁情况"
echo
echo
v4v6
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
if [[ -n $v6 ]]; then
get_ip_geo_info "$v6"
nonf="$geo_country"
nf6;chatgpt6;checkgpt;gemini6
v6Status=$(white "IPV6地址：\c" ; blue "$v6   $nonf" ; white " Netflix： \c" ; blue "$NF" ; white " ChatGPT： \c" ; blue "$chat" ; white " Gemini： \c" ; blue "$gemini")
else
v6Status=$(white "IPV6地址：\c" ; red "不存在IPV6地址")
fi
if [[ -n $v4 ]]; then
get_ip_geo_info "$v4"
nonf="$geo_country"
nf4;chatgpt4;checkgpt;gemini4
v4Status=$(white "IPV4地址：\c" ; blue "$v4   $nonf" ; white " Netflix： \c" ; blue "$NF" ; white " ChatGPT： \c" ; blue "$chat" ; white " Gemini： \c" ; blue "$gemini")
else
v4Status=$(white "IPV4地址：\c" ; red "不存在IPV4地址")
fi
echo "-----------------------------------------------------------------------"
white " ${v4Status}"
echo "-----------------------------------------------------------------------"
white " ${v6Status}"
echo "-----------------------------------------------------------------------"
echo
yellow "以上结果仅检测本地IP解锁情况，无法检测WARP出站分流的解锁情况"
echo
echo
white "=================================================================="
yellow " warp脚本使用说明："
yellow " 一、无限生成WARP-Wireguard配置信息（选项1）"
yellow " 可用于代理脚本的WARP-Wireguard出站账户更换或者自建节点"
echo
yellow " 二、安装WARP脚本（选项2与3）"
yellow " 作用：有机率全局解锁 Netflix 与 ChatGPT"
yellow " 提示：在使用支持WARP出站的代理脚本时，不建议再安装warp脚本"
yellow " 提示：wgcf与warp-go随意选择，哪个能装用哪个"
echo "-------------------------------------------------------------------"
green " 1. 生成并提取WARP-Wireguard节点配置文件、二维码"
green " 2. 选择 wgcf    方案进入WARP安装菜单"
green " 3. 选择 warp-go 方案进入WARP安装菜单"
green " 0. 退出脚本"
white "=================================================================="
echo
readp " 请输入数字【0-3】:" Input
case "$Input" in
 1 ) WGproxy;;
 2 ) warpyl && ONEWGCFWARP;;
 3 ) warpyl && ONEWARPGO;;
 * ) exit
esac
}
if [ $# == 0 ]; then
if [[ -n $(type -P warp-go) && -z $(type -P wg-quick) ]] && [[ -f '/usr/bin/cf' ]]; then
ONEWARPGO
elif [[ -n $(type -P warp-go) && -n $(type -P warp-cli) && -z $(type -P wg-quick) ]] && [[ -f '/usr/bin/cf' ]]; then
ONEWARPGO
elif [[ -z $(type -P warp-go) && -z $(type -P wg-quick) && -n $(type -P warp-cli) ]] && [[ -f '/usr/bin/cf' ]]; then
ONEWARPGO
elif [[ -n $(type -P wg-quick) && -z $(type -P warp-go) ]] && [[ -f '/usr/bin/cf' ]]; then
ONEWGCFWARP
elif [[ -n $(type -P wg-quick) && -n $(type -P warp-cli) && -z $(type -P warp-go) ]] && [[ -f '/usr/bin/cf' ]]; then
ONEWGCFWARP
else
startCFwarp
fi
fi
