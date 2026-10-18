# 桌面与跨端同步

更新：2026-10-19。Windows x64 为首个 PC 目标。1.6.0 聚焦校园代码与项目共享，构建、部署和设备验收状态分别记录在[验收记录](ACCEPTANCE.md)。

## 技术选择

电脑端同时提供[浏览器工作台](WEB.md)，适合直接访问和调试。Web 与 Windows 共享页面和远程数据；平台文件访问、会话与浏览器限制分别适配。Windows 保留独立发布。

采用 Flutter Windows，与 Android 共用项目社区、校园工具、数据仓库和认证流程；Web 使用相同业务代码。Electron 的 Chromium / Node.js 进程模型适合以网页为主体的桌面产品；Campulse 本轮沿用现有 Flutter 实现。

依据：[Flutter 桌面支持](https://docs.flutter.dev/platform-integration/desktop)、[Electron 进程模型](https://www.electronjs.org/docs/latest/tutorial/process-model)。复旦[旦挞](https://github.com/DanXi-Dev/DanXi)同样提供 Flutter 多端实现，可参考其跨端发布组织。

## 界面和操作

- 四个主板块为探索、我的仓库、校园、我的。宽度达到 980 时使用侧栏，1250 起展开标签；更窄的窗口使用底栏，切换时保留当前页面状态。
- 探索默认展示已审核项目，个人仓库管理自己的项目、GitHub 绑定与审核进度。项目详情集中 README、源码链接、关注和 Issue 式讨论。
- 校园下设课程与课表、快速访问、校园广场。课程支持搜索、置顶、CSV 导入及基本详情，通知读取远程记录；广场继续提供约球、竞赛组队、学习搭子和扩列。
- `Ctrl+1` 至 `Ctrl+4` 切换主板块，`Ctrl+K` 聚焦项目搜索，`Ctrl+R` 刷新云端数据。正在编辑的路由仍通过各自保存按钮提交。
- 页面渐入遵循系统减少动态效果设置，按钮保留鼠标悬停、键盘焦点与点击反馈。

## 数据怎样互通

| 数据 | 保存位置与读取方式 |
| --- | --- |
| 账号、个人课程与校园通知 | 两端连接同一 PocketBase，按对应页面刷新读回 |
| 服务收藏、课程置顶 | `user_favorites`，分别按服务分组与 `courses` 板块保存 |
| 项目、审核、讨论、Star | Campulse 自有社区集合，两端使用同一访问规则 |
| 校园广场、报名、讨论、兴趣名片 | `community_*` 集合；兴趣名片按本人公开开关读取 |
| 登录会话 | 各设备的系统安全存储 |
| 主题、语言、个性化昵称与头像样式 | 各设备偏好，按账号区分 |

界面从服务器重新读取数据。跨端测试应先保存，再刷新另一端，最后重启读回；协同编辑、实时推送和冲突合并列入后续开发。

旧笔记、PDF、复习卡片、学习成果及 `study_workspaces` 数据层保留，学习工作台已退出 1.6.0 客户端主流程。历史学习同步记录按对应版本追溯。

Windows 网页服务交给系统浏览器打开；Android 微信 OpenSDK 的拉起链路继续在手机验收。Windows 与 macOS、Linux 的原生插件和发布要求分别验证，本轮构建目标为 Windows x64。

## 获取 Windows 版

1. 打开 [Windows 预览 Release](https://github.com/Khk-NL/Campulse/releases/tag/campulse-desktop-preview)。
2. 核对 `Campulse-Windows.json` 的 `sourceCommit` 与构建链接。
3. 下载 `Campulse-Windows-x64.zip`，完整解压到一个目录。
4. 运行 `Campulse.exe`，保留同目录下的 DLL 和 `data` 文件夹。
5. 登录与手机相同的普通账号，验证邮箱后使用项目社区与校园广场。

应用采用预览发布，Windows 代码签名证书与安装器属于后续发布工作。系统显示来源提示时，先核对仓库、提交和 SHA256。

## 构建与部署

`.github/workflows/windows-release.yml` 在 main 的客户端变更后自动验证、构建并上传 ZIP、SHA256 和提交元数据，产物保存在 GitHub Release。Android 继续走原有云构建。

两端使用 `apps/mobile/config/eduwork.production.example.json` 中同一公开配置。当前项目主流程要求 PocketBase HTTPS 可达、目标迁移完成、普通账号可登录。原配置名与 AI 网关连接保留供存量模块使用，模型 Key 留在服务端。

校园广场需要 `1790210013_campus_square.js`。对现有服务器先备份，再执行增量迁移；详细步骤见[部署手册](REMOTE_DEPLOYMENT.md)。

本机继续开发：准备 Flutter 3.47.5、Visual Studio C++ 桌面工作负载与 Windows SDK；进入 `apps/mobile` 后获取锁定依赖，使用 `flutter run -d windows --dart-define-from-file=config/eduwork.production.example.json`。本机环境诊断以 `flutter doctor -v` 为准。

## 双端操作验收

1. 电脑创建项目并绑定 GitHub，手机进入本人仓库刷新，核对 README、源码链接与草稿状态。
2. 手机独立提交该项目审核，电脑刷新审核状态；管理员处理后，用另一账号从探索搜索该项目。
3. 另一账号关注项目并提出问题，作者在另一端回复、解决或重新开启，双方刷新核对记录。
4. 手机导入课程 CSV、置顶课程与收藏服务，电脑点顶部云刷新，核对课程、课表与收藏。
5. 两端打开远程通知，核对公告和个人条目；读取失败时检查页面反馈及重试。
6. 电脑发布约球或组队召集，手机另一账号报名、留言；电脑查看参加意向并回复。继续检查退出报名、兴趣名片、结束与重新开放召集。
7. 切换四个主入口，确认项目为第一入口、校园工具位于次级标签，个人页集中账号与项目消息。
8. 两端重启，核对会话与已保存内容；分别切换其他账号检查隔离。

API 验证可以检查权限与持久化；设备验收还需核对实际输入、文件选择、点击反馈和系统浏览器。
