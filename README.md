### 相关说明及注意点请查看[warp系列视频说明](https://www.youtube.com/playlist?list=PLMgly2AulGG-WqPXPkHlqWVSfQ3XjHNw8) [更新日志](https://ygkkk.blogspot.com/2022/09/cfwarp-script.html)

### 一、WARP多功能一键脚本，支持纯IPV4、纯IPV6的VPS直接安装，主流linux系统均支持
```
bash <(wget -qO- https://raw.githubusercontent.com/xxntmctx/warp-yg/main/CFwarp.sh)
```
或者
```
bash <(curl -Ls https://raw.githubusercontent.com/xxntmctx/warp-yg/main/CFwarp.sh)
```

#### 千万要注意：如出现IP丢失、VPS运行卡顿、脚本运行下载失败、无法进入脚本界面等现象，请用以下命令终止warp，再重启或者重装warp

 1、终止warp-go：
 ```kill -15 $(pgrep warp-go)```

 2、终止wgcf：
 ```systemctl stop wg-quick@wgcf```


### 1.1、新增：Gemini 解锁检测、IPv6 优先与 1Panel/Cron 自愈

- **主脚本内置 Gemini 检测与 IPv4/IPv6 优先级切换**：运行 `cf` 后，面板已同步检测 `Netflix`、`ChatGPT` 与 `Gemini（网页 + API + WIZ 时区/地区画像）`；菜单 `6. WARP其他选项` 新增第 `8` 项（一键部署/运行深度巡检自愈）与第 `9` 项（切换 `/etc/gai.conf` 系统 IPv4/IPv6 优先级并持久化至 `/root/warpip/ip_prefer`）。
- **1Panel / Cron 深度巡检自愈脚本（`gemini.sh`）**：
  - 自动识别端口实际托管进程（`wireproxy` / `warp-svc` / `warp-go` / `wgcf`），避免双客户端抢占 `40000` 端口导致重启无效。
  - 默认 `PREFER_IPV6=true`（支持 `--ipv6` / `--ipv4` / `--port <N>` / `--debug`），并优先验证代理真实转发路径 `Socks5h(auto)`。
  - 集成五维防假阳性检测：YouTube 裸请求 `hl=ru` 暴露检测 + Cookie 区域校验、Google `429`/`sorry` 拦截与 `enablejs` 如实标注、Gemini 网页/API 状态码及 `WIZ_global_data`（`rtQCxc` 时区偏移与 `vXmutd` 国家代码）拦截。
  - 1Panel 定时任务可直接执行：`bash /usr/local/bin/warp-gemini-check.sh --ipv6`（或直接将 [gemini.sh](gemini.sh) 内容粘贴至 1Panel Shell 定时任务）。
- **只读双机对照诊断脚本（`diag.sh`）**：用于快速对比正常机与异常机的 `v2node` 路由、双栈 Trace、YouTube 裸请求与 `WIZ_global_data` 关键字段，自动脱敏凭据。

```bash
curl -sSL https://raw.githubusercontent.com/xxntmctx/warp-yg/main/diag.sh | bash
```


---------------------------------------------------------------------

### 二、多平台优选WARP对端IP + 无限生成WARP-Wireguard配置 一键脚本，建议苹果手机与安卓手机在本地网络使用
```
curl -sSL https://gitlab.com/rwkgyg/CFwarp/raw/main/point/endip.sh -o endip.sh && chmod +x endip.sh && bash endip.sh
```

Replit平台一键无限生成WARP-Wireguard配置（须登录fork后才可运行）：https://replit.com/@yonggekkk/WARP-Wireguard-Register

--------------------------------------------------------------
### 三、Windows平台warp官方客户端优选对端IP应用程序

注意：默认只能在C盘或者桌面操作

使用方法：解压下载的（WIN端warp自选IP-v23.11.15.zip）文件，参考使用方法及视频教程

-----------------------------------------------------------
### WARP多功能VPS一键脚本界面图
![43bb749b327c7e3bd5c03f927f3a69d](https://github.com/yonggekkk/warp-yg/assets/121604513/61d2d6c0-9594-4799-9188-084bad886a66)

-----------------------------------------------------
### 交流平台：[甬哥博客地址](https://ygkkk.blogspot.com)、[甬哥YouTube频道](https://www.youtube.com/@ygkkk)、[甬哥TG电报群组](https://t.me/+jZHc6-A-1QQ5ZGVl)、[甬哥TG电报频道](https://t.me/+DkC9ZZUgEFQzMTZl)
-----------------------------------------------------
### 感谢支持！微信打赏甬哥侃侃侃ygkkk
![41440820a366deeb8109db5610313a1](https://github.com/user-attachments/assets/6ca29e1e-4db7-4669-964a-8b8d4a8d2997)

-----------------------------------------------------
### 感谢你右上角的star🌟
[![Stargazers over time](https://starchart.cc/xxntmctx/warp-yg.svg)](https://starchart.cc/xxntmctx/warp-yg)

--------------------------------------------------------------
#### 感谢WGCF源项目代码地址：https://github.com/ViRb3/wgcf
#### 感谢CoiaPrant，WARP-GO源项目代码地址：https://gitlab.com/ProjectWARP/warp-go
#### 相关功能参考来源： [P3terx](https://github.com/P3TERX/warp.sh)、[fscarmen](https://github.com/fscarmen/warp)、[热心的CF网友](https://github.com/badafans)提供的warp endpoint优选IP脚本及注册程序

---------------------------------------
#### 声明：
#### 所有代码来源于Github社区与ChatGPT的整合
