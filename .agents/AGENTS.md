# Project Rules & Engineering Contract (warp-yg)

## 1. 项目定位与目录契约

本仓库维护运行于 Linux VPS（Debian / Ubuntu / CentOS）的 Cloudflare WARP 一键管理、Gemini/ChatGPT/Netflix 解锁检测与 1Panel/Cron 自动化巡检自愈体系：

- `CFwarp.sh`：交互式主管理脚本（部署目标 `/usr/bin/cf`），保持与现有菜单编号及双核心架构（`ONEWARPGO` / `ONEWGCFWARP`）向后兼容。
- `gemini.sh`：独立自包含的五维深度巡检与自愈脚本（部署目标 `/usr/local/bin/warp-gemini-check.sh`），必须同时支持无参运行（适配 1Panel 编辑器直接粘贴执行）和参数化运行（`--ipv6` / `--ipv4` / `--port` / `--debug`）。
- `diag.sh`：只读跨机对照诊断脚本，严禁在脚本内执行任何写入/重启/修改系统配置的操作。
- `.agents/`：仓库自包含 AI 工程规范与领域技能目录，确保任意协作 Agent 接手时零上下文丢失。
- `tests/`：**本地敏感测试日志隔离目录**，已在 `.gitignore` 中屏蔽。

## 2. 安全红线 (Zero-Trust)

1. **严禁提交敏感数据**：`tests/` 目录、VPS 真实 IP、端口监听快照、节点密钥、Token、UUID、API Key 及账号密码绝对禁止提交至 Git 仓库或写入追踪文件。
2. **只读诊断脱敏**：修改或扩展 `diag.sh`、`gemini.sh`、`CFwarp.sh` 日志输出时，涉及读取 `v2node` / `xray` / `sing-box` / `wireguard` 配置文件的内容必须过滤 `password`、`token`、`secret`、`key`、`uuid`、`PrivateKey` 等敏感字段。
3. **非交互式 Git 提交**：执行自动化 Git 提交时必须使用 `git -c commit.gpgsign=false commit -m "..."`，严禁修改宿主全局 Git 签名配置。

## 3. 核心架构与业务边界

1. **不假设上游代理改配**：默认假设 `v2node` / `Xray` / `sing-box` 在多台节点采用统一配置将流量转发至 `127.0.0.1:40000`（`Socks5h(auto)`），问题修复与自愈策略应优先在 `warp-yg` 侧解决。
2. **禁止假阳性兜底**：
   - `gemini.sh` 与 `CFwarp.sh` 的检测逻辑必须保持判定口径一致（尤其是 `WIZ_global_data` 的 `rtQCxc` 时区偏移、`vXmutd` 国家码、YouTube 无 Cookie 裸请求 `hl=ru`、Google 搜索 `429`/`sorry` 与 `enablejs` 区分）。
   - 不允许将匹配失败的地区字段默认赋值为 `"正常"` 或直接放行 `"未知"` 关键风控信号。
3. **进程归属真实性**：任何自愈重启操作前必须基于 `ss -ntlp` 识别实际占用目标端口的进程（`wireproxy` vs `warp-svc`），禁止仅靠二进制存在与否盲目重启无关服务。
4. **IPv4 / IPv6 优先级持久化**：尊重用户通过 `/root/warpip/ip_prefer` 设置的 `v6` / `v4` 优先级，`first4()` 等安装钩子不得无条件覆盖 `/etc/gai.conf`。

## 4. 代码质量与验收门禁

1. **行尾与换行**：新增或重构的独立 Shell 脚本（如 `gemini.sh`、`diag.sh`）保持 Unix LF（`\n`）行尾格式，避免在 Linux 上出现 `$'\r'` 解析错误。
2. **去重与容错**：`CFwarp.sh` 内新增功能必须收敛为顶层共享函数（如 `get_ip_geo_info`、`check_gemini_unlock`），避免在 `ONEWARPGO` 与 `ONEWGCFWARP` 两段历史代码中重复实现；优先使用 `python3` 进行 JSON 解析并保留纯 Shell 正则回退。
3. **提交前必检门禁**：每次改动 `*.sh` 后、提交 Git 前，必须对所有修改过的脚本执行 `bash -n <script>.sh` 语法校验并确认 `git status -s` 无 `tests/` 或密钥文件泄露。
