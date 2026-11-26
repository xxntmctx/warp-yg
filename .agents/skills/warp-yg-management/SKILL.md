---
name: warp-yg-management
description: >-
  Manage, configure, diagnose, and maintain Cloudflare WARP (warp-go, wgcf,
  warp-svc, wireproxy) on Linux VPS with CFwarp.sh, gemini.sh (1Panel/Cron
  Google/Gemini/YouTube probe & self-heal), and diag.sh.
---

# Cloudflare WARP 管理、Gemini 探测自愈与排障技能

## 1. 快速定位文件

- 主脚本：[CFwarp.sh](../../CFwarp.sh)（快捷方式 `/usr/bin/cf`）
- 1Panel / Cron 自愈巡检：[gemini.sh](../../gemini.sh)（部署路径 `/usr/local/bin/warp-gemini-check.sh`）
- 双机只读对照诊断：[diag.sh](../../diag.sh)

## 2. 标准运维命令

- **一键更新 `cf`**：在 `cf` 菜单选择 `8`，或执行：
  `curl -sSL -o /usr/bin/cf "https://raw.githubusercontent.com/xxntmctx/warp-yg/main/CFwarp.sh?t=$(date +%s)" && chmod +x /usr/bin/cf && cf`
- **开启 1Panel / Cron 巡检**：在 `cf` 菜单选择 `6` -> `8` -> `1`（立即测试）或 `2`（写入每 10 分钟 Cron）；1Panel Shell 任务填写 `bash /usr/local/bin/warp-gemini-check.sh --ipv6`。
- **调试模式运行巡检**：`bash /usr/local/bin/warp-gemini-check.sh --ipv6 --debug`

## 3. 核心排障准则

1. **端口冲突 (`wireproxy` vs `warp-svc`)**：若 `ss -ntlp | grep 40000` 显示 `wireproxy` 占用端口且同时存在 `warp-svc`，`wireproxy` 会导致 `Socks5h(auto)` 强制走 IPv4 且无法通过 `warp-cli` 换号；应停用 `wireproxy` 并交由 `warp-svc` 托管（`systemctl disable --now wireproxy && systemctl restart warp-svc`）。
2. **赫尔辛基 (`HEL`) 俄区画像 (`rtQCxc=-180` / `hl=ru`)**：当 `gemini.google.com` 的 `WIZ_global_data` 返回 `rtQCxc: -180`（在芬兰冬令时 `+0200` 下代表被判为莫斯科 UTC+3）或 YouTube 裸请求返回 `hl=ru` 时，网页会提示地区不支持，此时必须判定异常并触发自愈洗 IP。
3. **修改后校验**：本地修改任一 `.sh` 文件后，执行 `bash -n CFwarp.sh`、`bash -n gemini.sh`、`bash -n diag.sh` 全量语法验证通过后再提交。
