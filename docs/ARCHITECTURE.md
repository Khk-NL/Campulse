# 系统架构

更新：2026-10-21。主链路为 Flutter Android / Windows / Web → PocketBase，覆盖校园项目、审核、讨论、收藏与校园辅助工具。1.6.2 复用 Node.js 网关接入 GitHub 和项目分析；旧学习页面按存量实现保留。

截至 2026-10-21，1.6.2 Web、项目网关与收藏库迁移已部署。当前 `1.6.3+12` 正开发社区交流信息流，沿用已有服务、集合和依赖；具体来源提交、测试数量与发布状态统一以[验收记录](ACCEPTANCE.md)为准。

主导航为探索、我的仓库、校园、我的。前两页分别使用 `ForgePage` 的公开项目和个人仓库查询；`CampusPage` 收拢课程/课表、快速访问、校园广场。导航和子标签按首次访问装配，已访问页面保留状态；全局搜索聚焦项目查询。课程卡片、课表和旧目录搜索复用的课程详情只显示基础信息。新建草稿保存后进入个人仓库，公开展示仍走逐项目审核。

Web 使用 `/app/` 子路径，业务通过同源 `/api/` 连接 PocketBase，项目集成通过 `/ai/v1/forge/*` 请求网关。`config/web.json` 选择浏览器 origin，本机代理与线上静态站点可复用同一 bundle。历史 PDF 模块的原生文件访问通过条件导入隔离，Web 实现读取已登录用户的 PocketBase 附件仓库。微信原生注册限定在 Android。构建、调试及发布见[Web 说明](WEB.md)。

## 运行路径

```text
Flutter Android / Windows / Web（共享 Dart 业务层）
 ├─ PocketBase HTTPS API → 账号、项目、审核、讨论、收藏、课程与校园广场
 ├─ /ai/v1/forge/* → 项目集成网关 → GitHub / 模型服务
 └─ CampusLauncher → 外部网页 / 微信 OpenSDK

Caddy（现有共享服务器的 80/443）
 ├─ /ai/* → 127.0.0.1:8787（项目集成与存量学习网关，去掉 /ai 前缀）
 └─ 其他路径 → 127.0.0.1:8090
                  ├─ PocketBase API 与受保护附件
                  └─ pb_public：官网、运营台、/app/ 浏览器工作台
```

Android APK、校验文件与版本元数据由 GitHub Release assets 分发，工作流不再向 main 回写二进制。运行时服务配置见 `apps/mobile/config/eduwork.production.example.json`，仍使用临时域名。正式域名切换按[域名恢复](DOMAIN_FILING.md)执行。

## 模块与代码

| 模块 | 主要位置 | 职责 |
| --- | --- | --- |
| 启动、会话与偏好 | `apps/mobile/lib/core/` | 启动探测、安全存储会话、主题与语言 |
| 公共目录与搜索 | `apps/mobile/lib/data/repositories/`、`features/apps/` | 远程目录、分类、收藏和服务启动 |
| 校园工具 | `features/campus/campus_page.dart`、`features/study/course_hub_page.dart`、`features/timetable/` | 课程基础信息、课表、CSV 与校园通知；另含公共快速访问和广场 |
| 项目社区 | `apps/mobile/lib/features/apps/forge_page.dart`、`forge_repository.dart` | 我的仓库、逐项目审核、发现、Star、排序和讨论组合筛选 |
| 社区交流（1.6.3 开发中） | `features/apps/forge_community_page.dart`、`ForgeRepository.communityThreads` | 跨公开项目的频道、关键词、Star 筛选、时间排序与讨论分页，进入原项目或讨论 |
| 项目内容阅读 | `features/apps/forge_markdown.dart` | 复用 Markdown 渲染依赖，统一 README、讨论、回复及编辑预览，封装代码复制与外链打开 |
| 个人收藏库 | `features/apps/forge_library_page.dart`、`forge_library_repository.dart` | 分类、标签、备注、批量整理、个人分析和版本消息 |
| 集成设置与请求 | `features/apps/forge_integrations.dart` | 按账号保存本机 Key 与模型选择，使用当前会话调用项目集成网关 |
| 项目集成网关 | `apps/ai-gateway/src/forge.mjs` | GitHub 元数据与 Stars 读取、逐项导入、订阅刷新和 README 分析 |
| 校园广场 | `apps/mobile/lib/features/community/` | 竞赛/运动/学习/扩列召集、报名、讨论与自愿公开名片 |
| 自适应工作区 | `features/shared/widgets/workspace_layout.dart`、`features/shell/app_shell.dart` | 桌面侧栏、紧凑底栏、响应式网格与键盘导航 |
| Windows 运行与发布 | `apps/mobile/windows/`、`.github/workflows/windows-release.yml` | 原生窗口、品牌图标、锁定依赖构建和 ZIP Release |
| 历史学习实现 | `features/study/` 其余学习页面、网关 notebook 管线 | 原笔记、AI 与复习实现，当前主导航和课程详情已断开入口 |
| 官网与运营台 | `deploy/pocketbase/pb_public/` | 产品页面、分层管理界面、元数据驱动记录维护 |
| 数据结构与访问规则 | `experiments/pocketbase/pb_migrations/`、`deploy/pocketbase/pb_migrations/` | 基础集合与生产增量迁移 |
| 高校适配 | `adapters/ecnu/`、客户端高校配置 | 校方接口契约和学校信息 |
| TypeScript 领域契约 | `packages/` | 课程规则、标签归一化、Launcher、SDK 和插件契约 |

客户端采用 ChangeNotifier 与 InheritedNotifier 组织状态。Repository 隔离界面和数据服务；生产配置使用 PocketBase。启动的另一条分支保留旧 REST 客户端，正式启动已移除本地演示数据回退，测试样本位于客户端测试目录。

探索、个人仓库和校园快速访问独立呈现加载状态。项目搜索使用可释放的控制器和 300ms 防抖，键盘提交与清空会取消待执行查询。学校平台对比及集成层级见[路线图](ROADMAP.md#学校平台对比与集成)。

2026-10-20 的 1.6.1 加入 Star 与排序，在 `ForgeRepository.projects` 组合后交给服务器分页；Star 使用 `forge_stars_via_repository.owner` 反向关系限定本人，公开视图继续叠加同校、已审核和公开条件。讨论查询同时保留项目 ID、类型、处理状态和标题/正文关键词。筛选控件位于异步列表之外，读取中仍可继续输入；查询条件变化回到第一页，新建内容后重置旧筛选。

Markdown 原文保持现有字段，组件以 `flutter_markdown_plus` 和 `markdown` 渲染。标题、列表、表格、代码块在客户端呈现，代码和表格各自横向滚动。编辑预览读取同一个控制器，保存原文；网页链接复用系统打开工具，相关协议和相对地址有明确反馈。

## 项目收藏与集成（1.6.2）

本节对应 2026-10-21 已部署的功能；实际连接与验收范围见[验收记录](ACCEPTANCE.md)。

`ForgeLibraryPage` 通过 `ForgeLibraryRepository` 读取本人 Star、分类、收藏整理、订阅与历史版本事件。Star 决定收藏库展示的项目，`forge_bookmarks` 单独保存分类、标签、备注和分析；取消 Star 后这些整理内容继续保留，再次 Star 时按同一项目读回。分类锁定用于应用 AI 建议时保留原分类，手工整理仍可修改。

GitHub 功能经过 `/v1/forge/github`、`github/stars` 与 `github/import` 读取仓库资料和个人 Stars，用户逐项选择导入。新项目保存为本人的 `private/draft`，公开上架仍由管理员逐项审核。GitHub 侧使用只读请求，Campulse 的 Star 与 GitHub Star 分别维护。

订阅刷新由用户触发 `/v1/forge/releases/refresh`，版本事件按用户、项目和外部版本 ID 去重。进入页面读取 PocketBase 已保存的事件；刷新结果写入事件和订阅检查时间，已读状态同步到账号。

`/v1/forge/analyze` 根据项目 README 生成摘要、使用场景、入门步骤、风险与分类标签建议，结果存入当前用户的 bookmark。用户确认后应用个人分类和标签，公共项目内容保持原值。网关继续使用已验证的 PocketBase 会话校验归属。

`ForgeIntegrationStore` 沿用 `FlutterSecureStorage`，以 PocketBase origin 和用户 ID 划分本机设置，保存 GitHub Token、各模型提供方的 Key 与模型名称。数据库保存整理结果和元数据，服务器默认 Key 由环境变量提供。模型请求支持 ChatECNU、DeepSeek（默认 `deepseek-flash`）；EduChat 使用管理员配置的兼容 `/chat/completions` 服务地址，模型宿主单独部署。

ChatECNU 已有真实 JSON 调用及项目分析验证。DeepSeek 真实 Key、个人 GitHub Stars Token、自部署 EduChat 地址尚缺，对应适配由 mock 测试覆盖，尚未完成这些配置下的真实连接验证；具体证据统一见[验收记录](ACCEPTANCE.md)。

## 社区交流（1.6.3，2026-10-21 开发中）

`ForgeCommunityPage` 通过 `ForgeRepository.communityThreads` 查询 `forge_discussions` 并展开 `repository`。服务器过滤同时限制华师大、学校归属已核验、已审核和公开项目，再组合频道类型、标题/正文/项目话题关键词、当前用户 Star 关系和创建或更新时间排序；每页 20 条，条件变化重置分页。

频道复用 `question`、`idea`、`update`、`bug`，加上全部视图。信息流保持项目来源，可进入现有项目详情或完整讨论及回复；发帖先选择公开项目，复用现有 Markdown 编辑器和讨论写入。讨论与回复无需预审核，项目公开继续审核；不新增集合、迁移或第三方依赖。组织和交互参考 CSDN 的范围见[界面设计](DESIGN.md)。

## 数据与权限

公共快速访问由管理员维护，收藏属于用户。个人课程按 owner 组织。社区项目持有作者关系，讨论、回复和关注继承项目可见范围。1.6.2 新增的分类、书签、订阅和版本事件按 owner 隔离，相关项目须为本人项目或已审核的华师大公开项目。存量笔记、卡片和成果继续按 owner 及 courseId 管理，旧计划和学习过程保存在用户工作台快照。集合映射见[数据模型](DATA_MODEL.md)。

普通用户使用 PocketBase 会话，登录态持久化到设备安全存储，启动尝试刷新；网络超时保留已有会话。存量学习网关通过服务端 auth-refresh 校验已验证账号，使用请求者令牌读取资料，再检查用户与课程归属。

运营台使用 PocketBase 超级管理员身份，具备全库权限。普通用户访问规则、运营人员操作范围和后续分级角色分别管理。

## 工作区功能与实现

| 用户操作 | 界面与状态 | 数据路径及边界 |
| --- | --- | --- |
| 搜课程、置顶和查看详情 | `course_hub_page.dart`、`course_details_sheet.dart` | 个人课程按 owner 读取；置顶使用 `user_favorites` 的 `courses` 分组，详情显示基础信息 |
| 查服务、收藏和打开入口 | `apps_page.dart`、CampusLauncher | 管理员公共目录，收藏按用户保存；网页由系统浏览器打开 |
| 项目发布、审核、讨论和 Star | Forge 页面与 Repository | 私有草稿 → 逐项审核 → 公共发现；讨论继承项目可见范围 |
| 整理收藏、查看更新与项目分析 | `ForgeLibraryPage`、Library Repository、Forge Gateway | 个人分类与书签独立保存；GitHub 读取和模型分析结果归当前用户 |
| 按频道浏览、发起社区交流（1.6.3 开发中） | `ForgeCommunityPage` → `communityThreads` → 原讨论与项目入口 | 仅聚合已审核华师大公开项目，复用讨论/回复；发帖按公开项目关联 |
| 发起召集、报名和讨论 | `community_page.dart`、`community_repository.dart` | `community_posts/interests/replies`；发起人和报名者可读报名留言 |
| 查看“我报名的” | 对报名集合按 owner 分页，展开 `post` 关系 | 每页 20 条，学校/类型/校区/搜索在服务端关联过滤，保留分页总数 |
| 编辑兴趣名片 | 用户主动公开，按 owner 查找后新增或更新 | 唯一 owner 索引；并发创建时重新查找本人记录再更新 |
| 管理召集与用户内容 | 运营台按用户/发起人/全站分层视图 | 报名分为本人报名与收到的报名；多行字段使用 textarea 保留换行 |
| 跨端导航与发布 | `app_shell.dart`、Android/Windows CI | 共享业务层，按窗口宽度切换侧栏/底栏；产物与源码提交一起发布 |

界面布局与数据权限分开：窗口变宽只改变呈现方式，Repository 与 PocketBase 访问规则保持一致。当前同步为保存后刷新。实时通知、冲突合并和运营审计见[路线图](ROADMAP.md)。

## 存量学习实现

以下实现保留在源码与数据层中，自 2026-10-19 的 1.6.0 起主导航和课程基础详情已断开对应入口。历史验收结果按原版本追溯。

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
