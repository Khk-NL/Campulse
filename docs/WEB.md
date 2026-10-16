# 浏览器工作台

更新：2026-10-16。Web 与 Android / Windows 共用 Flutter 页面、PocketBase 账号和 AI 网关。官网承载公开介绍，`/app/` 承载登录后的课程、笔记、复习和社区。

当前访问 [Campulse Web 工作台](https://campus.allezafrique.cn/app/)，使用与手机相同的普通账号。上线版本与操作证据见[验收记录](ACCEPTANCE.md#公网发布结果)。

## 构建与访问

在 `apps/mobile` 执行：

```powershell
flutter pub get --enforce-lockfile
flutter build web --release --base-href=/app/ --no-web-resources-cdn --no-wasm-dry-run --dart-define-from-file=config/web.json --dart-define=CAMPUS_APP_VERSION=1.5.0
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
flutter run -d chrome --web-port=5030 --dart-define=POCKETBASE_URL=https://campus.allezafrique.cn --dart-define=CAMPUS_EDUWORK_GATEWAY_URL=http://127.0.0.1:5027/ai --dart-define=CAMPUS_APP_VERSION=1.5.0
```

此模式使用 Flutter 开发服务器和浏览器调试工具；AI 经本机代理，代理仅向本机 HTTP origin 提供跨域响应。与 Release 的同源模式分别配置。调试过程保留实际登录流程，Key 留在远程服务端。

## 发布

`web-release.yml` 在 main 客户端变更后分析、测试、构建，上传 `Campulse-Web.zip`、SHA256 和 `version.json` 到 [Web 预览 Release](https://github.com/Khk-NL/Campulse/releases/tag/campulse-web-preview)。构建时自托管 CanvasKit，采用 JavaScript 输出；WebAssembly 属于后续独立兼容性目标。

现有服务器增量发布：核对 ZIP 的来源提交和 SHA256，上传 ZIP 与 `deploy/update-web.sh`，使用 sudo 执行脚本并传入 ZIP 的绝对路径。脚本先验证静态入口，再将原 `pb_public/app` 移入 `/opt/campus/backups/web-*` 恢复点并替换。网站首页、运营台、数据库与其他站点保持原样。当前 CI 负责构建和 Release 发布；服务器静态目录通过此脚本升级。

Release 与在线 `/app/version.json` 分别记录源码提交；在线状态以实际读回和浏览器验收为准。正式域名恢复继续按[域名流程](DOMAIN_FILING.md)推进。

现网 Caddy 对 `/app/*` 启用 zstd/gzip 与 `Cache-Control: no-cache`，浏览器重新校验静态入口和脚本，Wasm 按正确 MIME 返回。站点模板见 `deploy/campus.Caddyfile.example`；调整共享服务器配置前保留恢复点，验证后平滑重载。其他站点与 API 反代继续沿用原配置。

## 平台差异与验收

- 受保护 PDF 由普通用户上传 PocketBase，再通过文件令牌读取；Web 使用云端资料库。原生端的本地 PDF 存储通过条件导入隔离。
- 浏览器登录态由安全存储插件的 Web 实现管理，运行环境使用 HTTPS 或 localhost。浏览器数据清理和隐私模式会影响会话保留。
- 微信 OpenSDK 使用 Android 原生通道；浏览器服务链接交给浏览器处理，小程序操作继续按手机端流程验收。
- 主题、键盘、窗口宽度和减少动画沿用共享实现。快捷键可能受浏览器保留键影响，工具栏按钮同时保留。
- 验收逐项检查登录、刷新、账号隔离、PDF / Markdown 导入、笔记编辑、AI 证据、复习评分、项目讨论、退出和重载。API、组件测试与实际浏览器结果分别登记到[验收记录](ACCEPTANCE.md)。

参考：[Flutter Web 初始化](https://docs.flutter.dev/platform-integration/web/initialization)、[子路径部署](https://docs.flutter.dev/ui/navigation/url-strategies)。
