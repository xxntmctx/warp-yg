---
name: warp-yg-management
description: >-
  Manage, configure, diagnose, and maintain Cloudflare WARP (warp-go, wgcf,
  warp-svc, wireproxy) on Linux VPS with CFwarp.sh, gemini.sh (1Panel/Cron
  Google/Gemini/YouTube probe & self-heal), and diag.sh.
---

# Cloudflare WARP 管理、Gemini 探测自愈与排障指南 (warp-yg)

本仓库提供 Linux VPS（Debian 10–13 / Ubuntu 20–24 / CentOS）下的 Cloudflare WARP 多方案部署、Gemini/Netflix/ChatGPT 解锁检测，以及面向 1Panel/Cron 的自动巡检自愈能力。

## 核心组件与职责

| 文件 | 职责定位 | 运行方式 |
| :--- | :--- | :--- |
| `CFwarp.sh` | 主交互式管理脚本（安装后快捷命令 `/usr/bin/cf`），涵盖方案一 (`warp-go`/`wgcf`)、方案二 (`Socks5-WARP`)、方案三 (WireGuard 配置) 与工具箱 | `bash CFwarp.sh` 或 `cf` |
| `gemini.sh` | 1Panel/Cron 专用 Google / Gemini / YouTube 五维深度探测与分级自愈脚本 | `bash gemini.sh [--ipv6\|--ipv4] [--port N] [--debug]` |
| `diag.sh` | 只读对照诊断脚本，采集端口归属、`v2node` 路由（已脱敏）、双栈 Trace、YouTube 裸请求及 Gemini `WIZ_global_data` | `bash diag.sh [port]` |
| `.gitignore` | 隔离本地敏感实测日志目录 `tests/` 及 `.env` / `.dev.vars` / `*.log` / `*.key` / `*.pem` | Git 自动忽略 |

## 核心工作流

### 1. 主菜单与状态面板 (`CFwarp.sh`)
- 解锁检测并行覆盖 **Netflix**、**ChatGPT** 与 **Gemini**（通过 `get_ip_geo_info` 使用 `python3` 安全解析 `ip-api.com` / `api.ip.sb`）。
- `ShowSOCKS5()` 会通过 `ss -ntlp` 识别监听端口的真实托管进程（`wireproxy` 或 `warp-svc`），并同时探测 IPv6 与 IPv4 出口。
- 菜单 `6. WARP其他选项`：
  - **选项 8 (`gemini_monitor_tool`)**：安装/更新 `/usr/local/bin/warp-gemini-check.sh`、配置每 10 分钟 Cron 自愈、查看 `/var/log/warp-gemini.log`。
  - **选项 9 (`toggle_ip_priority`)**：切换 `/etc/gai.conf` 的 IPv6/IPv4 优先级，并持久化至 `/root/warpip/ip_prefer`，防止方案一切换时 `first4()` 强制覆盖为 IPv4 优先。

### 2. 深度巡检与自愈 (`gemini.sh`)
- **真实通道优先**：`socks5`/`wireproxy` 模式先探测 `Socks5h(auto)`（与 `v2node`/Xray/sing-box 实际域名转发路径一致），再结合 `--resolve` 校验 IPv6 优先级。
- **五维防假阳性判定**：
  1. WARP 隧道：`cdn-cgi/trace` 验证 `warp=on|plus` 与有效出口 IP。
  2. CF 边缘地区：拦截受限国家代码（`CN|HK|MO|RU|IR|KP|BY|SY|CU`）。
  3. YouTube 裸请求 + Cookie 校验：先发无 Cookie 裸 `HEAD` 探测真实 `Location` 是否暴露 `hl=ru`；再校验 `consent` 与 `contentRegion`。
  4. Google 搜索：拦截 `429`/`403`/`5xx`/`sorry/index`/`reCAPTCHA`，命中 `/httpservice/retry/enablejs` 时如实标注 `JS挑战` 而非误报 `正常`。
  5. Gemini 网页 + API + `WIZ_global_data`：拦截非 `200`、异常跳转及 `generativelanguage.googleapis.com` 地区封锁；解析 `WIZ_global_data` 中的 `rtQCxc`（如芬兰冬令时 `+0200` 却被判 `-180` 莫斯科 `UTC+3`）与 `vXmutd` 国家代码。
- **按真实进程分级自愈**：`wireproxy` 轮换 `/etc/wireguard/proxy.conf` 的 `Endpoint` 并重启；`warp-svc` 先重连、第 2 次起注销重注册新设备（非 `Limited` 付费账户）；`warp-go`/`wgcf` 轮换 Endpoint。

## 常见故障定位速查

1. **自愈多次但出口 IP 不变**：用 `ss -ntlp | grep 40000` 检查是否同时运行了 `wireproxy` 与 `warp-svc` 抢占端口；`wireproxy` 使用固定 WireGuard 密钥且默认走 IPv4，推荐停用冲突进程并交由 `warp-svc` 托管（`systemctl disable --now wireproxy && systemctl restart warp-svc`）。
2. **`curl gemini.google.com/app` 返回 200 但浏览器提示不支持地区**：说明前端 JS 读取 `WIZ_global_data` 后渲染受限，使用 `bash gemini.sh --debug` 或 `bash diag.sh` 核对 `rtQCxc` 与 YouTube 裸请求 `hl=`。
