# Campulse 功能与代码实现

更新：2026-10-10。验收状态见 [验收与下一步](E2E_ACCEPTANCE_20261010.md)。

## 用户工作区与公共目录

数据归属与集合映射见 [用户工作区](USER_WORKSPACE_20261010.md)。运营台通过 `workspaceViews/workspaceFilter` 组织用户、课程和项目关联视图；高级数据库表单保留全库维护能力。公共快速访问由管理员维护，收藏由 `user_favorites` 保存用户关系。个人通知和待办通过目录的可选 `owner` 指定收件人，公共公告与活动保留单一来源。

Flutter 正式启动仅装配远程仓库，测试数据及内存演示仓库位于 `test/fixtures`。`FavoritesController` 按用户隔离缓存，`CampusFavoritesRepository` 定义可替换的数据接口，PocketBase 适配器实现云端收藏读写。

## 项目审核与 GitHub 绑定

`ForgePage/ForgeProjectPage` 展示个人全部仓库、逐项目审核状态及 GitHub 链接；`ForgeRepository.saveProject` 保存草稿、`submitProject` 独立申请上架。公开发现和搜索查询批准且学校归属已核验的项目。

PocketBase 迁移 `1790210011` 在服务端执行可见范围及审核字段写入限制。运营台 `AdminClient.reviewProject` 与 `admin.mjs` 提供待审队列、归属材料、核验确认、通过及退回意见。讨论/回复继承项目访问权限，按 Issue 模式直接交流。具体流程见 [项目审核](PROJECT_REVIEW.md)。

## 运行架构

```text
Flutter APK
 ├─ PocketBaseSession → PocketBase HTTPS API → 用户与业务数据
 ├─ 课程知识工作台 → /ai/v1/* → Node 网关 → ChatECNU
 └─ CampusLauncher → Android OpenSDK / WebView / 外部应用

Caddy
 ├─ /ai/* → 127.0.0.1:8787
 └─ 其他路径 → 127.0.0.1:8090 → 官网、运营台、PocketBase
```

生产数据库采用 PocketBase。普通用户登录态由系统安全存储持久化，启动时刷新会话；网络超时保留已有会话。管理员使用独立运营台。`apps/api` 的 NestJS/Prisma 实现作为历史实现保留，部署范围为 loopback。

## 功能到代码

| 功能 | 主要代码 | 数据与约束 |
| --- | --- | --- |
| 账号、注册、验证与重置 | `apps/mobile/lib/core/pocketbase_session.dart`、登录/个人页面 | `users`；AI 调用要求已验证用户 |
| 校园快捷入口 | `features/apps/apps_page.dart`、`campus_entry.dart`、`core/launcher/campus_launcher.dart` | `campus_content`；发布状态控制公开范围 |
| 课程列表与课程表 | `features/study/`、`features/timetable/`、课程 CSV 导入实现 | `user_courses`；用户归属隔离，节次依学校配置校验 |
| 计划、完成归档、学习过程 | `features/study/` 与工作台 Repository | `study_workspaces`；按用户保存工作台快照 |
| Markdown/PDF 笔记 | `features/study/`、`course_note_repository.dart`、`pdf_text_extraction.dart` | `course_notes`；Markdown 2 MB、PDF 20 MB，附件受保护 |
| 原文检索、证据问答 | `apps/ai-gateway/src/notebook.mjs`、`server.mjs` | 用户及课程范围过滤，证据携带页/行/来源信息 |
| 测验、闪卡、导图、智能体对话 | 知识工作台 UI 与网关 notebook 路由 | `course_artifacts`；成果编辑、测验成绩及历史分页 |
| 卡片复习 | 卡片 Repository、网关评分路由 | `course_review_cards`；服务端 ts-fsrs，历史保留 500 条 |
| 个性化主题与资料 | `core/app_state.dart`、个人页面 | 主题、昵称、头像按现有设备/账号偏好保存 |
| 数据运营 | `deploy/pocketbase/pb_public/assets/admin-client.mjs`、`admin.mjs` | 根据真实集合元数据生成表单、筛选与编辑；超级管理员权限 |

具体目录可用 `rg --files apps/mobile/lib` 查询；表格按模块入口列出，避免逐文件重复维护。

## 校园社区：围绕项目交流

社区直接位于“应用 → 校园作品”。快捷使用继续承担校园工具启动；社区承担项目发现与协作交流。

| 模块 | 实现 | 数据集合 |
| --- | --- | --- |
| 项目发现、搜索、我的仓库、分页 | `features/apps/forge_page.dart` | `forge_repositories` |
| 项目介绍、README、话题、公开/私有、编辑 | `ForgeProjectPage`、项目编辑表单 | `forge_repositories` |
| 问答、建议、问题反馈、项目进展 | 项目“讨论与问题”页、讨论表单 | `forge_discussions` |
| 回复、解决问题、重新开启 | `ForgeDiscussionPage` | `forge_replies`、讨论状态 |
| 项目关注与计数 | 项目详情关注按钮 | `forge_stars` |
| Repository 接口 | `features/apps/forge_repository.dart` | PocketBase SDK，过滤参数经 `client.filter` 转义 |
| 集合与权限 | `1790210010_forge_community.js` | 四个独立集合，关联删除与唯一索引 |

公开项目和交流内容可读；写入要求已验证账号。仓库由所有者编辑，问题由作者或仓库所有者管理；回复由作者编辑。私有仓库的讨论、回复和关注记录随仓库权限隔离。公开转私有后，原讨论作者的读取和修改权限同步收紧。关注以 `(owner, repository)` 唯一索引去重。

这版实现项目级交流工作流。Git 对象存储、分支、合并请求、文件版本、通知、成员协作和贡献统计列入后续迭代；个人主页与成就位于辅助层，优先级在交流流程之后。Campulse 社区数据独立保存，外部仓库地址属于可选关联。

## 学习能力与开源来源

网关采用 Campulse headless 管线，结合 EduWork 的已登记模块和 ChatECNU 服务。`eduworkRevision` 表示参考/导入模块的来源提交；运行实现由 `integration: campulse-headless` 标识。开源来源及许可见 [开源使用说明](OPEN_SOURCE_USAGE.md)。

扫描 PDF 的 OCR、向量语义检索、长期对话扩展、笔记本地/云端互迁、跨设备个人资料同步仍在扩展清单。现有 Repository 与领域模型保持分层，以便将来替换数据服务。

## 最新修正（2026-10-10）

- 小程序可启动性结合原生 transport 状态判断；异步返回时检查页面消息宿主生命周期。
- HTTP 测试助手正确传递 `Response` 构造错误，新增非法状态码回归。
- 运营台测试覆盖集合分页、单记录读取和类型筛选；公开页面文案检查自动遍历页面。
- TypeScript CI 限定只读仓库权限和任务超时。
- 旧阶段记录移入 `docs/archive/`，原路径保留导航。
- 社区表单控制器随 Dialog 生命周期释放；重复提交在请求期间锁定按钮，失败时保留输入并提供反馈。
- 关注状态读回后开放操作，仓储操作前读取当前记录；讨论翻页仅加载对应讨论页。新回复跳到最后一页，发送期间离开页面安全结束回调。作者按维护者、当前用户或社区成员显示，讨论状态随刷新读回。

## 部署顺序

1. 备份现有 PocketBase 数据目录，并确认恢复点。
2. 安装经过验证的 `1790210010_forge_community.js`，执行迁移。
3. 验证两名普通用户的社区写入、回复与访问隔离。
4. 更新运营台静态文件，使四个社区集合显示中文分区和对应操作。
5. 推送 main，由 GitHub Actions 生成 APK；核对 Release 的 sourceCommit。
6. 安装云构建 APK，补齐社区与学习工作台的设备点击验收。

保留既有数据与服务器环境，升级采用增量迁移。
