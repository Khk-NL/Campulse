# 系统架构

更新：2026-10-16。当前产品由 Flutter Android / Windows 客户端、PocketBase、Node.js AI 网关和静态官网/运营台组成。

## 运行路径

```text
Flutter Android / Windows（共享 Dart 业务层）
 ├─ PocketBase HTTPS API → 账号、课程、笔记、计划、收藏、社区
 ├─ /ai/v1/* → Node 网关 → EduWork 核心模块 + ChatECNU
 └─ CampusLauncher → 外部网页 / 微信 OpenSDK

Caddy（现有共享服务器的 80/443）
 ├─ /ai/* → 127.0.0.1:8787（去掉 /ai 前缀）
 └─ 其他路径 → 127.0.0.1:8090
                  ├─ PocketBase API 与受保护附件
                  └─ pb_public：官网与运营台
```

当前 APK 公开地址见 `apps/mobile/config/eduwork.production.example.json`，仍使用临时域名。正式域名切换按[域名恢复](DOMAIN_FILING.md)执行。

## 模块与代码

| 模块 | 主要位置 | 职责 |
| --- | --- | --- |
| 启动、会话与偏好 | `apps/mobile/lib/core/` | 启动探测、安全存储会话、主题与语言 |
| 公共目录与搜索 | `apps/mobile/lib/data/repositories/`、`features/apps/` | 远程目录、分类、收藏和服务启动 |
| 课程与学习 | `apps/mobile/lib/features/study/`、`features/timetable/` | 课程表、CSV、笔记、计划和知识工作台 |
| 项目社区 | `apps/mobile/lib/features/apps/forge_page.dart`、`forge_repository.dart` | 我的仓库、逐项目审核、发现、讨论、回复和关注 |
| 校园广场 | `apps/mobile/lib/features/community/` | 竞赛/运动/学习/扩列召集、报名、讨论与自愿公开名片 |
| 自适应工作区 | `features/shared/widgets/workspace_layout.dart`、`features/shell/app_shell.dart` | 桌面侧栏、紧凑底栏、响应式网格与键盘导航 |
| Windows 运行与发布 | `apps/mobile/windows/`、`.github/workflows/windows-release.yml` | 原生窗口、品牌图标、锁定依赖构建和 ZIP Release |
| AI 与学习产物 | `apps/ai-gateway/src/server.mjs`、`notebook.mjs` | 鉴权、原文检索、模型调用、产物校验与 FSRS |
| 官网与运营台 | `deploy/pocketbase/pb_public/` | 产品页面、分层管理界面、元数据驱动记录维护 |
| 数据结构与访问规则 | `experiments/pocketbase/pb_migrations/`、`deploy/pocketbase/pb_migrations/` | 基础集合与生产增量迁移 |
| 高校适配 | `adapters/ecnu/`、客户端高校配置 | 校方接口契约和学校信息 |
| TypeScript 领域契约 | `packages/` | 课程规则、标签归一化、Launcher、SDK 和插件契约 |

客户端采用 ChangeNotifier 与 InheritedNotifier 组织状态。Repository 隔离界面和数据服务；生产配置使用 PocketBase。启动的另一条分支保留旧 REST 客户端，正式启动已移除本地演示数据回退，测试样本位于客户端测试目录。

应用页的快速访问和社区独立呈现加载状态；目录请求失败时分区切换保持可用。项目搜索使用可释放的控制器和 300ms 防抖，键盘提交与清空会取消待执行查询。学校平台对比及集成层级见[路线图](ROADMAP.md#学校平台对比与集成)。

## 数据与权限

公共快速访问由管理员维护，收藏属于用户。个人课程、笔记、卡片和成果通过 owner 及 courseId 组织；计划和学习过程保存在用户工作台快照。社区项目持有作者关系，讨论、回复和关注继承项目可见范围。集合映射见[数据模型](DATA_MODEL.md)。

普通用户使用 PocketBase 会话，登录态持久化到设备安全存储，启动尝试刷新；网络超时保留已有会话。网关通过服务端 auth-refresh 校验已验证账号，使用请求者令牌读取资料，再检查用户与课程归属。

运营台使用 PocketBase 超级管理员身份，具备全库权限。普通用户访问规则、运营人员操作范围和后续分级角色分别管理。

## 工作区功能与实现

| 用户操作 | 界面与状态 | 数据路径及边界 |
| --- | --- | --- |
| 从首页安排任务 | `home_page.dart` → 计划页 → 学习 Repository | 用户工作台快照，完成后归档；双端先保存再刷新 |
| 搜课程、置顶和进入笔记本 | `course_hub_page.dart`、`course_notebook_view.dart` | 个人课程按 owner 读取；置顶使用 `user_favorites` 的 `courses` 分组 |
| 查看教材、提问和生成成果 | 宽屏资料/提问/工作台三栏，手机分区切换 | 受保护附件 → AI 网关鉴权 → 用户资料 → 模型 → 用户成果 |
| 查服务、收藏和打开入口 | `apps_page.dart`、CampusLauncher | 管理员公共目录，收藏按用户保存；网页由系统浏览器打开 |
| 项目发布、审核、讨论和 Star | Forge 页面与 Repository | 私有草稿 → 逐项审核 → 公共发现；讨论继承项目可见范围 |
| 发起召集、报名和讨论 | `community_page.dart`、`community_repository.dart` | `community_posts/interests/replies`；发起人和报名者可读报名留言 |
| 查看“我报名的” | 对报名集合按 owner 分页，展开 `post` 关系 | 每页 20 条，学校/类型/校区/搜索在服务端关联过滤，保留分页总数 |
| 编辑兴趣名片 | 用户主动公开，按 owner 查找后新增或更新 | 唯一 owner 索引；并发创建时重新查找本人记录再更新 |
| 管理召集与用户内容 | 运营台按用户/发起人/全站分层视图 | 报名分为本人报名与收到的报名；多行字段使用 textarea 保留换行 |
| 跨端导航与发布 | `app_shell.dart`、Android/Windows CI | 共享业务层，按窗口宽度切换侧栏/底栏；产物与源码提交一起发布 |

界面布局与数据权限分开：窗口变宽只改变呈现方式，Repository 与 PocketBase 访问规则保持一致。当前同步为保存后刷新；同一工作台的并行修改以后保存的快照为准。实时通知、冲突合并和运营审计见[路线图](ROADMAP.md)。

## AI 集成

当前运行方式为 `campulse-headless`：复用 EduWork 的 parser、tokenizer、mindmap、evidence-labels，结合 Campulse 鉴权、资料读取、ChatECNU 和成果存储。`eduworkRevision` 表示导入模块的上游来源提交。

状态接口根据模型配置和成果集合可用性返回能力。完整接口与容量边界见[课程知识工作台](COURSE_NOTEBOOK.md)。

## 历史实现与演进

`apps/api` 保存 NestJS/Prisma/PostgreSQL 实现，当前部署范围采用 loopback，产品主链路使用 PocketBase。其认证、授权及限流属于再次公开部署前的工作。

TypeScript 包按已有依赖保持单向分层：Launcher 类型 → 领域模型 → 高校适配契约 → ECNU 实现。Flutter 使用 Dart 模型与 Repository 映射。迁移其他数据库时保留业务 ID、归属、课程关系、附件及成果契约，并以双用户隔离测试验证。
