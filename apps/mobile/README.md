# Campulse 移动端

Flutter Android 客户端，包含首页、课程、应用和我的。产品介绍见[仓库首页](../../README.md)，当前运行与测试见[开发指南](../../docs/DEVELOPMENT.md)。

## 主要目录

- lib/core：启动、会话、配置、主题和服务启动器。
- lib/data：校园目录模型与远程数据仓储。
- lib/features：课程、笔记、计划、知识工作台、项目社区和个人页面。
- lib/l10n：中英语言资源。
- test：Widget、模型、Repository 及测试样本。
- android：OpenSDK 接入与 Android 构建。
- config：公开后端地址配置。

生产连接 PocketBase 和 AI 网关，个人数据按用户隔离；本地测试样本位于测试目录。课程工作台的部分本机存储实现仍作为独立能力保留，正式配置按启动及 Repository 选择。

## 开发与发布

在此目录运行 flutter pub get，再使用 flutter run --dart-define-from-file=config/eduwork.production.example.json。

改动完成后运行 flutter analyze --no-pub 和 flutter test --no-pub。APK 使用 main 的 GitHub Actions 构建，[Release](https://github.com/Khk-NL/Campulse/releases/tag/campulse-preview)提供预览包与源码信息。

微信 AppID、普通用户会话、管理员及模型凭据分别管理。连接域名、权限阻塞与设备验收见[验收记录](../../docs/ACCEPTANCE.md)。
