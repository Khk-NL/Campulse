# 系统架构

更新：2026-10-19。当前主链路为 Flutter Android / Windows / Web → PocketBase，覆盖校园项目、审核、讨论、收藏与校园辅助工具。Node.js AI 网关和旧学习模块保留历史实现，1.6.0 客户端主流程已撤下对应入口。

主导航为探索、我的仓库、校园、我的。前两页分别使用 `ForgePage` 的公开项目和个人仓库查询；`CampusPage` 收拢课程/课表、快速访问、校园广场。导航和子标签按首次访问装配，已访问页面保留状态；全局搜索聚焦项目查询。课程卡片、课表和旧目录搜索复用的课程详情只显示基础信息。新建草稿保存后进入个人仓库，公开展示仍走逐项目审核。

Web 使用 `/app/` 子路径，当前业务通过同源 `/api/` 连接 PocketBase，`/ai/` 保留存量学习服务。`config/web.json` 选择浏览器 origin，本机代理与线上静态站点可复用同一 bundle。历史 PDF 模块的原生文件访问通过条件导入隔离，Web 实现读取已登录用户的 PocketBase 附件仓库。微信原生注册限定在 Android。构建、调试及发布见[Web 说明](WEB.md)。

## 运行路径

```text
Flutter Android / Windows / Web（共享 Dart 业务层）
 ├─ PocketBase HTTPS API → 账号、项目、审核、讨论、收藏、课程与校园广场
 └─ CampusLauncher → 外部网页 / 微信 OpenSDK

Caddy（现有共享服务器的 80/443）
 ├─ /ai/* → 127.0.0.1:8787（存量学习网关，去掉 /ai 前缀）
 └─ 其他路径 → 127.0.0.1:8090
                  ├─ PocketBase API 与受保护附件
                  └─ pb_public：官网、运营台、/app/ 浏览器工作台
```

当前 APK 公开地址见 `apps/mobile/config/eduwork.production.example.json`，仍使用临时域名。正式域名切换按[域名恢复](DOMAIN_FILING.md)执行。

## 模块与代码

| 模块 | 主要位置 | 职责 |
| --- | --- | --- |
| 启动、会话与偏好 | `apps/mobile/lib/core/` | 启动探测、安全存储会话、主题与语言 |
| 公共目录与搜索 | `apps/mobile/lib/data/repositories/`、`features/apps/` | 远程目录、分类、收藏和服务启动 |
| 校园工具 | `features/campus/campus_page.dart`、`features/study/course_hub_page.dart`、`features/timetable/` | 课程基础信息、课表、CSV 与校园通知；另含公共快速访问和广场 |
| 项目社区 | `apps/mobile/lib/features/apps/forge_page.dart`、`forge_repository.dart` | 我的仓库、逐项目审核、发现、讨论、回复和关注 |
| 校园广场 | `apps/mobile/lib/features/community/` | 竞赛/运动/学习/扩列召集、报名、讨论与自愿公开名片 |
| 自适应工作区 | `features/shared/widgets/workspace_layout.dart`、`features/shell/app_shell.dart` | 桌面侧栏、紧凑底栏、响应式网格与键盘导航 |
| Windows 运行与发布 | `apps/mobile/windows/`、`.github/workflows/windows-release.yml` | 原生窗口、品牌图标、锁定依赖构建和 ZIP Release |
| 历史学习实现 | `features/study/` 其余学习页面、`apps/ai-gateway/` | 原笔记、AI 与复习实现，当前主导航和课程详情已断开入口 |
| 官网与运营台 | `deploy/pocketbase/pb_public/` | 产品页面、分层管理界面、元数据驱动记录维护 |
| 数据结构与访问规则 | `experiments/pocketbase/pb_migrations/`、`deploy/pocketbase/pb_migrations/` | 基础集合与生产增量迁移 |
| 高校适配 | `adapters/ecnu/`、客户端高校配置 | 校方接口契约和学校信息 |
| TypeScript 领域契约 | `packages/` | 课程规则、标签归一化、Launcher、SDK 和插件契约 |

客户端采用 ChangeNotifier 与 InheritedNotifier 组织状态。Repository 隔离界面和数据服务；生产配置使用 PocketBase。启动的另一条分支保留旧 REST 客户端，正式启动已移除本地演示数据回退，测试样本位于客户端测试目录。

探索、个人仓库和校园快速访问独立呈现加载状态。项目搜索使用可释放的控制器和 300ms 防抖，键盘提交与清空会取消待执行查询。学校平台对比及集成层级见[路线图](ROADMAP.md#学校平台对比与集成)。

## 数据与权限

公共快速访问由管理员维护，收藏属于用户。个人课程按 owner 组织。社区项目持有作者关系，讨论、回复和关注继承项目可见范围。存量笔记、卡片和成果继续按 owner 及 courseId 管理，旧计划和学习过程保存在用户工作台快照。集合映射见[数据模型](DATA_MODEL.md)。

普通用户使用 PocketBase 会话，登录态持久化到设备安全存储，启动尝试刷新；网络超时保留已有会话。存量学习网关通过服务端 auth-refresh 校验已验证账号，使用请求者令牌读取资料，再检查用户与课程归属。

运营台使用 PocketBase 超级管理员身份，具备全库权限。普通用户访问规则、运营人员操作范围和后续分级角色分别管理。

## 工作区功能与实现

| 用户操作 | 界面与状态 | 数据路径及边界 |
| --- | --- | --- |
| 搜课程、置顶和查看详情 | `course_hub_page.dart`、`course_details_sheet.dart` | 个人课程按 owner 读取；置顶使用 `user_favorites` 的 `courses` 分组，详情显示基础信息 |
| 查服务、收藏和打开入口 | `apps_page.dart`、CampusLauncher | 管理员公共目录，收藏按用户保存；网页由系统浏览器打开 |
| 项目发布、审核、讨论和 Star | Forge 页面与 Repository | 私有草稿 → 逐项审核 → 公共发现；讨论继承项目可见范围 |
| 发起召集、报名和讨论 | `community_page.dart`、`community_repository.dart` | `community_posts/interests/replies`；发起人和报名者可读报名留言 |
| 查看“我报名的” | 对报名集合按 owner 分页，展开 `post` 关系 | 每页 20 条，学校/类型/校区/搜索在服务端关联过滤，保留分页总数 |
| 编辑兴趣名片 | 用户主动公开，按 owner 查找后新增或更新 | 唯一 owner 索引；并发创建时重新查找本人记录再更新 |
| 管理召集与用户内容 | 运营台按用户/发起人/全站分层视图 | 报名分为本人报名与收到的报名；多行字段使用 textarea 保留换行 |
| 跨端导航与发布 | `app_shell.dart`、Android/Windows CI | 共享业务层，按窗口宽度切换侧栏/底栏；产物与源码提交一起发布 |

界面布局与数据权限分开：窗口变宽只改变呈现方式，Repository 与 PocketBase 访问规则保持一致。当前同步为保存后刷新。实时通知、冲突合并和运营审计见[路线图](ROADMAP.md)。

## 存量学习实现

以下实现保留在源码与数据层中，1.6.0 主导航和课程基础详情已断开对应入口。历史验收结果按原版本追溯。

| 历史操作 | 保留实现 | 数据路径及边界 |
| --- | --- | --- |
| 从原首页安排任务 | `home_page.dart` → 计划页 → 学习 Repository | 用户工作台快照，完成后归档；双端先保存再刷新 |
| 进入课程笔记本 | `course_notebook_view.dart` | 原课程学习空间，按课程组织笔记与资料 |
| 查看教材、提问和生成成果 | 宽屏资料/提问/工作台三栏，手机分区切换 | 受保护附件 → AI 网关鉴权 → 用户资料 → 模型 → 用户成果 |
| 连续复习 | `ReviewSessionPage` 固定本轮到期队列，逐张回想、评分与统计 | 复用 `ReviewCardRepository.review`，远程 FSRS 保存成功后推进；失败保留当前卡片，提交期间锁定重复操作 |
| 整理课程资料 | 同一查询结果切换列表/卡片，支持标题/更新时间排序与复制文字 | 复用课程笔记仓库和受保护 PDF；响应式网格按行懒加载 |

旧工作台的并行修改以后保存的快照为准。存量 AI 集成方式为 `campulse-headless`：复用 EduWork 的 parser、tokenizer、mindmap、evidence-labels，结合 Campulse 鉴权、资料读取、ChatECNU 和成果存储。`eduworkRevision` 表示导入模块的上游来源提交。

状态接口根据模型配置和成果集合可用性返回能力。完整接口与容量边界见[课程知识工作台](COURSE_NOTEBOOK.md)。

## 历史实现与演进

`apps/api` 保存 NestJS/Prisma/PostgreSQL 实现，当前部署范围采用 loopback，产品主链路使用 PocketBase。其认证、授权及限流属于再次公开部署前的工作。

TypeScript 包按已有依赖保持单向分层：Launcher 类型 → 领域模型 → 高校适配契约 → ECNU 实现。Flutter 使用 Dart 模型与 Repository 映射。迁移其他数据库时保留业务 ID、归属、课程关系、附件及成果契约，并以双用户隔离测试验证。
