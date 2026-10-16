# 开发指南

更新：2026-10-16。产品范围见[项目首页](../README.md)，继续工作先读[交接清单](HANDOFF.md)。

## 环境与初始化

使用 Node.js 22+、仓库 packageManager 指定的 pnpm，以及 Android CI 使用的 Flutter 版本。具体版本以 `package.json`、`apps/mobile/pubspec.yaml` 和 `.github/workflows/android-release.yml` 为准。开发机路径由本人环境决定。

```sh
pnpm install --frozen-lockfile
cd apps/mobile
flutter pub get
```

先确认已有工具与依赖，按改动范围安装。凭据存放在 Git 忽略目录或服务器私有配置；示例配置只包含字段和公开服务地址。

## 客户端运行

在仓库根目录执行：

```sh
cd apps/mobile
flutter run --dart-define-from-file=config/eduwork.production.example.json
```

该文件包含公开 PocketBase 和 AI 网关地址。微信小程序调试另传 `--dart-define=CAMPUS_WECHAT_APP_ID=你的移动应用AppID`；正式预览构建由 CI Secret 提供。

调试本机后端时，设备需要能访问开发机；标准 Android 模拟器通常使用 10.0.2.2，MuMu 地址按实际网络与端口确认。手机正式使用 HTTPS。普通 App 账号与 PocketBase 超级管理员分别使用。

Windows 开发在同一目录使用 `flutter run -d windows --dart-define-from-file=config/eduwork.production.example.json`，准备 Visual Studio C++ 桌面工作负载和 Windows SDK。云构建、ZIP 安装及跨端验证见[桌面说明](DESKTOP.md)。

## 改动落点

| 需求 | 优先查看 |
| --- | --- |
| 页面与交互 | `apps/mobile/lib/features/` |
| 文案与语言 | `apps/mobile/lib/l10n/` 及相关页面 |
| 主题与偏好 | `apps/mobile/lib/core/theme/`、AppState |
| 课程、笔记和同步 | study 模块的 Repository |
| 校园社区 | forge 页面、Repository 与对应迁移 |
| 校园广场与组队 | `features/community/` 与 `1790210013_campus_square.js` |
| 桌面与响应式布局 | `windows/`、`workspace_layout.dart`、`app_shell.dart` |
| AI 与检索 | `apps/ai-gateway/src/` |
| 官网和运营台 | `deploy/pocketbase/pb_public/` |
| 数据字段与权限 | 两处 PocketBase 迁移目录 |
| 学校适配 | `adapters/ecnu/` 和客户端高校配置 |

修改前读现有实现，复用 Repository、主题令牌和表单模式。新增功能同时核对用户归属、失败反馈、持久化读回及所需迁移。

## 验证

完成一个修改单元后运行相关测试，提交前按风险补齐：

```sh
pnpm test
node scripts/check-pb-migrations.mjs
cd apps/mobile
flutter analyze --no-pub
flutter test --no-pub
```

`pnpm test` 包含 TypeScript 构建、五组契约冒烟、网关及运营台/目录相关 Node 测试。迁移结构检查仅验证文件与回调，真实数据库迁移使用 `forge-acceptance.mjs --local` 等独立脚本；全新库仍需验证完整迁移链。

公网验收会创建或修改专用测试记录，先读脚本，确认目标和凭据，按[验收流程](ACCEPTANCE.md)执行。界面回归测试、API 通过、APK 点击和重启读回分别记录。

## 提交与发布

工作分支统一使用 main。按文件明确暂存，保留无关工作区修改，确认差异中凭据与本地产物的范围。

Android 工作流仅在移动端、网关或工作流相关路径变动时自动触发，也支持手动 dispatch。纯文档更新通常只推送文档。APK 从 GitHub Release 获取，构建来源以 Release JSON 的 sourceCommit 为准。

服务器更新与 Git 推送分别执行，流程见[部署手册](REMOTE_DEPLOYMENT.md)。部署涉及迁移时，先数据库 → 网关/运营台 → APK → 双用户与设备验收。

## 文档更新

长期文档使用固定名称。功能变化更新架构或对应主题；部署变化更新运维与验收；待办集中到路线图与交接清单。保留第三方许可及来源提交，发布说明使用自然、可核实的表述。
