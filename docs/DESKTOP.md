# 桌面与跨端同步

更新：2026-10-16。Windows x64 为首个 PC 目标。构建、部署和设备验收状态分别记录在[验收记录](ACCEPTANCE.md)。

## 技术选择

电脑端同时提供[浏览器工作台](WEB.md)，适合直接访问和调试。Web 与 Windows 共享页面和远程数据；平台文件访问、会话与浏览器限制分别适配。Windows 保留独立发布。

采用 Flutter Windows，与 Android 共用页面、数据仓库和认证流程。当前项目的课程、PDF 阅读、笔记、计划与社区已经用 Dart 实现，复用这些代码比另建 Electron 网页前端更直接。Electron 的 Chromium / Node.js 进程模型适合以网页为主体的桌面产品；Campulse 本轮保持单套客户端业务代码。

依据：[Flutter 桌面支持](https://docs.flutter.dev/platform-integration/desktop)、[Electron 进程模型](https://www.electronjs.org/docs/latest/tutorial/process-model)。复旦[旦挞](https://github.com/DanXi-Dev/DanXi)同样提供 Flutter 多端实现，可参考其跨端发布组织。

## 界面和操作

- 四个主板块继续为首页、应用、课程、我的。宽度达到 980 时使用侧栏，1250 起展开标签；更窄的窗口使用底栏，切换时保留当前页面状态。
- 首页分列展示个人计划和今日安排，课程列表支持搜索、置顶、导入与进入学习空间。
- 课程学习空间在 1180 宽度起并排显示资料、提问和学习工作台；课程计划单独切换。手机保持原分区操作。
- `Ctrl+1` 至 `Ctrl+4` 切换主板块，`Ctrl+K` 搜索，`Ctrl+R` 刷新云端数据。正在编辑的路由仍通过各自保存按钮提交。
- 页面渐入遵循系统减少动态效果设置，按钮保留鼠标悬停、键盘焦点与点击反馈。

## 数据怎样互通

| 数据 | 保存位置与读取方式 |
| --- | --- |
| 账号、课程、笔记及 PDF、复习卡片、学习成果 | 两端连接同一 PocketBase；各课程页刷新读回 |
| 计划和学习记录 | 用户的 `study_workspaces` 快照；保存后另一端刷新 |
| 服务收藏、课程置顶 | `user_favorites`，分别按服务分组与 `courses` 板块保存 |
| 项目、审核、讨论、Star | Campulse 自有社区集合，两端使用同一访问规则 |
| 校园广场、报名、讨论、兴趣名片 | `community_*` 集合；兴趣名片按本人公开开关读取 |
| 登录会话 | 各设备的系统安全存储 |
| 主题、语言、个性化昵称与头像样式 | 各设备偏好，按账号区分 |

界面从服务器重新读取数据。并行修改同一工作台时，后保存的快照生效；协同编辑、实时推送和冲突合并列入后续开发。跨端测试应先保存，再刷新另一端，最后重启读回。

Windows 网页服务交给系统浏览器打开；Android 微信 OpenSDK 的拉起链路继续在手机验收。Windows 与 macOS、Linux 的原生插件和发布要求分别验证，本轮构建目标为 Windows x64。

## 获取 Windows 版

1. 打开 [Windows 预览 Release](https://github.com/Khk-NL/Campulse/releases/tag/campulse-desktop-preview)。
2. 核对 `Campulse-Windows.json` 的 `sourceCommit` 与构建链接。
3. 下载 `Campulse-Windows-x64.zip`，完整解压到一个目录。
4. 运行 `Campulse.exe`，保留同目录下的 DLL 和 `data` 文件夹。
5. 登录与手机相同的普通账号，验证邮箱后使用学习和社区功能。

应用采用预览发布，Windows 代码签名证书与安装器属于后续发布工作。系统显示来源提示时，先核对仓库、提交和 SHA256。

## 构建与部署

`.github/workflows/windows-release.yml` 在 main 的客户端变更后自动验证、构建并上传 ZIP、SHA256 和提交元数据，产物保存在 GitHub Release。Android 继续走原有云构建。

两端使用 `apps/mobile/config/eduwork.production.example.json` 中同一公开配置。运行条件为 PocketBase 与 AI 网关 HTTPS 可达、目标迁移完成、普通账号可登录。模型 Key 保留在服务端。

校园广场需要 `1790210013_campus_square.js`。对现有服务器先备份，再执行增量迁移；详细步骤见[部署手册](REMOTE_DEPLOYMENT.md)。

本机继续开发：准备 Flutter 3.47.5、Visual Studio C++ 桌面工作负载与 Windows SDK；进入 `apps/mobile` 后获取锁定依赖，使用 `flutter run -d windows --dart-define-from-file=config/eduwork.production.example.json`。本机环境诊断以 `flutter doctor -v` 为准。

## 双端操作验收

1. 手机保存一门课程，电脑刷新课程列表，核对课程名称和 ID。
2. 手机置顶课程、收藏服务，电脑点顶部云刷新，核对两个状态。
3. 电脑上传 PDF / Markdown 并编辑一条笔记，手机进入同一课程刷新，查看正文与附件。
4. 手机完成一项计划并评分卡片，电脑刷新，查看归档与下次复习时间。
5. 电脑发布校园召集，手机另一账号报名、留言；电脑查看参加意向并回复。
6. 手机退出报名、收回兴趣名片，电脑刷新核对可见范围。
7. 结束召集后换账号尝试报名，再重新开放复测。
8. 两端重启登录，核对会话与已保存内容；分别切换其他账号检查隔离。

API 验证可以检查权限与持久化；设备验收还需核对实际输入、文件选择、点击反馈和系统浏览器。
