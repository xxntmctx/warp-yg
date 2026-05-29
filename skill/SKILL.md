---
name: warp-yg-management
description: >-
  Manage, configure, and maintain Cloudflare WARP client configurations on VPS.
  Enables routing setup, Netflix/ChatGPT unlock detection, local Socks5 proxy,
  and background monitoring.
---

# Cloudflare WARP 管理与诊断工具 (warp-yg)

该技能提供了一套在 Linux VPS 机器（支持 Ubuntu, Debian, CentOS）上使用 `CFwarp.sh` 脚本对 Cloudflare WARP 进行一键配置、维护及状态诊断的操作规范。

## 运行环境与前置依赖

脚本依赖以下系统包，主要运行于 Linux 系统，且必须以 `root` 用户执行：
- `curl`, `wget`, `openssl`, `bc`, `python3`, `screen`, `qrencode`

## 常见操作指引

主要的 CLI 入口是当前仓库下的 `CFwarp.sh`（在安装后会生成软链接 `/usr/bin/cf`）。

### 1. 启动交互菜单
在 VPS 环境中执行以下命令进入交互菜单：
```bash
bash CFwarp.sh
# 或在全局安装后直接运行
cf
```

### 2. 核心功能方案
- **方案一（安装/切换内核）：** 使用 `warp-go` 或 `wgcf` (WireGuard) 将出站流量接管。支持配置单栈 IPv4、单栈 IPv6 或双栈 IPv4+IPv6。
- **方案二（Socks5 本地代理）：** 安装官方 `cloudflare-warp` 客户端，在本地监听指定的 Socks5 代理端口（默认 40000），仅作为本地代理而不接管全局出站流量。
- **方案三（提取配置文件）：** 提取 WARP-Wireguard 配置文件并生成二维码，方便其他设备扫码或导入使用。

### 3. 系统维护与优化
- **连接自动监测（`WARP-UP.sh`）：** 使用 `screen` 后台运行连接守护，定时检测连接状态。当连接中断时进行重试，连续 5 次重试失败会自动关闭并恢复 VPS 的原生 IP。
- **网络优化（MTU 自动设置）：** 动态测试最佳 MTU 吞吐值并写入配置文件中。
- **账户升级：** 支持升级/切换为 WARP 普通账户、WARP+ 账户（需提供 26 位 License 密钥）或 WARP Teams (Zero Trust 团队 Token) 账户。
- **内核互换：** 允许在 `warp-go` 内核和 `wgcf-warp` 内核之间一键切换。

## 诊断与解锁报告检测
在脚本启动或查询状态时，会对以下核心服务进行解锁检测：
- **Netflix (NF) 解锁检测：** 通过测试 `https://www.netflix.com/title/70143836`。返回 `200`（完整解锁非自制剧）、`404`（仅自制剧）、`403`（不能看）。
- **ChatGPT 解锁检测：** 检测 `https://chat.openai.com` 与客户端 `https://ios.chat.openai.com` 的连接情况，分析是否可以完整解锁网页和客户端。
