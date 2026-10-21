# 浏览器工作台

更新：2026-10-21。Web 与 Android / Windows 共用 Flutter 页面和 PocketBase 账号。官网承载公开介绍，`/app/` 以校园代码与项目共享为主。

1.6.3 主导航为“探索 / 我的仓库 / 校园 / 我的”。默认探索已审核的校园相关项目；个人仓库整理 GitHub 绑定、README 与逐项目审核状态，并展示本人全部项目。项目详情承接关注、问题和回复；社区交流按频道组织帖子，收藏与订阅集中管理分类、标签备注、版本消息及项目分析。校园保留课程与课表、通知、官方快速访问，以及约球、组队和扩列的校园广场。笔记、PDF、AI 学习和复习卡片退出客户端主流程，原数据层与网关保留为存量实现。

当前访问 [Campulse Web 工作台](https://campus.allezafrique.cn/app/)，使用与手机相同的普通账号。上线版本与操作证据见[验收记录](ACCEPTANCE.md)。

## 构建与访问

在 `apps/mobile` 执行：

```powershell
flutter pub get --enforce-lockfile
flutter build web --release --base-href=/app/ --no-web-resources-cdn --no-wasm-dry-run --dart-define-from-file=config/web.json --dart-define=CAMPUS_APP_VERSION=1.6.3
```

然后在仓库根目录运行：

```powershell
pnpm web:serve
```

打开 `http://127.0.0.1:5027/app/`。本机服务只监听回环地址，静态文件来自 `apps/mobile/build/web`，`/api/` 与 `/ai/` 转发到现有公网服务。目录外文件保持隔离；请求携带原用户会话。结束调试时在该终端按 Ctrl+C。

`CAMPULSE_WEB_UPSTREAM` 可指定测试服务器的 HTTP(S) origin，`CAMPULSE_WEB_PORT` 可修改端口，`CAMPULSE_WEB_ROOT` 可切换构建目录。默认连接 `https://campus.allezafrique.cn`；会产生真实用户数据，建议使用专用验收账号。

## 开发调试与热重载

保持上面的本机代理运行，另开终端进入 `apps/mobile`：

```powershell
flutter run -d chrome --web-port=5030 --dart-define=POCKETBASE_URL=https://campus.allezafrique.cn --dart-define=CAMPUS_EDUWORK_GATEWAY_URL=http://127.0.0.1:5027/ai --dart-define=CAMPUS_APP_VERSION=1.6.3
```

此模式使用 Flutter 开发服务器和浏览器调试工具，与 Release 的同源模式分别配置。项目、审核和社区记录使用 PocketBase，GitHub 集成及项目分析经 `/ai/` 转发到网关。调试过程保留实际登录流程，个人 Key 按账号保存在当前设备，服务共享 Key 由服务器配置。

## 发布

`web-release.yml` 在 main 客户端变更后分析、测试、构建，上传 `Campulse-Web.zip`、SHA256 和 `version.json` 到 [Web 预览 Release](https://github.com/Khk-NL/Campulse/releases/tag/campulse-web-preview)。构建时自托管 CanvasKit，采用 JavaScript 输出；WebAssembly 属于后续独立兼容性目标。

现有服务器增量发布：核对 ZIP 的来源提交和 SHA256，上传 ZIP 与 `deploy/update-web.sh`，使用 sudo 执行脚本并传入 ZIP 的绝对路径。脚本先验证静态入口，再将原 `pb_public/app` 移入 `/opt/campus/backups/web-*` 恢复点并替换。网站首页、运营台、数据库与其他站点保持原样。当前 CI 负责构建和 Release 发布；服务器静态目录通过此脚本升级。

Release 与在线 `/app/version.json` 分别记录源码提交；在线状态以实际读回和浏览器验收为准。正式域名恢复继续按[域名流程](DOMAIN_FILING.md)推进。

现网 Caddy 对 `/app/*` 启用 zstd/gzip 与 `Cache-Control: no-cache`，浏览器重新校验静态入口和脚本，Wasm 按正确 MIME 返回。站点模板见 `deploy/campus.Caddyfile.example`；调整共享服务器配置前保留恢复点，验证后平滑重载。其他站点与 API 反代继续沿用原配置。

## 平台差异与验收

- 浏览器登录态由安全存储插件的 Web 实现管理，运行环境使用 HTTPS 或 localhost。浏览器数据清理和隐私模式会影响会话保留。
- 微信 OpenSDK 使用 Android 原生通道；浏览器服务链接交给浏览器处理，小程序操作继续按手机端流程验收。
- 主题、键盘、窗口宽度和减少动画沿用共享实现。快捷键可能受浏览器保留键影响，工具栏按钮同时保留。
- 1.6.3 验收逐项检查登录、探索搜索、创建/绑定项目、审核状态、他人发现、关注、社区频道及讨论回复、收藏分类、订阅消息、项目分析、退出和重载；校园侧检查课表 CSV、通知、收藏及广场报名。API、组件测试与实际浏览器结果分别登记到[验收记录](ACCEPTANCE.md)。

此前的 PDF、笔记、AI 学习与复习操作证据按原版本保留。其受保护附件、平台条件导入和网关实现继续留在源码中，当前导航按本页的项目社区范围组织。构建与发布结果以实际产物及验收记录为准。

参考：[Flutter Web 初始化](https://docs.flutter.dev/platform-integration/web/initialization)、[子路径部署](https://docs.flutter.dev/ui/navigation/url-strategies)。
