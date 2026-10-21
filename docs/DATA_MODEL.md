# 数据模型与归属

更新：2026-10-21。现网业务数据库为 PocketBase（内置 SQLite）。集合结构由基础迁移与生产迁移共同定义；Prisma schema 属于旧 API 实现。1.6.2 收藏库迁移已在生产执行，1.6.3 社区交流复用现有集合；执行与验证证据统一见[验收记录](ACCEPTANCE.md)。

## 业务层级

```text
用户
 ├─ 校园 GitHub
 │   ├─ 个人仓库 → 收到的讨论与回复
 │   ├─ 社区项目 → 参与的讨论与回复、Star
 │   ├─ 社区交流 → 已审核公开项目的跨项目讨论信息流（1.6.3 开发中）
 │   └─ 收藏与订阅 → 分类、标签、备注、项目分析、版本事件
 ├─ 校园工具 → 个人课程 / 课表 / 通知与待办
 ├─ 校园广场 → 个人召集 / 报名意向 / 活动讨论 / 兴趣名片
 └─ 收藏 → 引用公共服务或入口

公共目录
 ├─ 官方小程序与官网
 └─ 校园公告与活动
```

原课程笔记、PDF、复习卡片、学习成果与计划继续保存在历史学习集合，客户端主入口以项目社区和校园辅助工具为主。

## PocketBase 集合

校园广场由 `1790210013_campus_square.js` 定义；用户、活动关系级联删除。活动由发起人手动结束，报名表示参加意向。兴趣名片的公开开关独立于账号信息。邮箱验证证明该邮箱的控制权，学校归属仍按项目审核流程核验。

课程置顶复用 `user_favorites` 的 `board = courses`、`entryKey = course.id`，沿用 owner 隔离和跨端读取；服务收藏的既有板块键保持。个人学习内容同步采用现有仓库接口，见[桌面与同步](DESKTOP.md)。

| 集合 | 内容 | 归属与读取边界 |
| --- | --- | --- |
| `users` | 普通账号与账号资料 | 用户自己的记录；管理员维护 |
| `community_posts` | 竞赛、运动、学习、扩列召集；类型、校区、时间与状态 | ECNU 范围；已验证邮箱用户可读，发起人编辑/结束/重新开放 |
| `community_interests` | 报名昵称与留言 | owner + post；报名者和发起人可读，每人每活动一条 |
| `community_replies` | 召集下的讨论 | 已验证邮箱用户可读；开放召集可回复；作者及发起人可删除 |
| `community_profiles` | 昵称、简介、兴趣技能、校区、公开开关 | 每用户一份；公开记录供已验证邮箱用户读取，本人维护 |
| `user_courses` | 导入课程与时间规则 | owner |
| `course_notes` | 笔记正文、PDF、时间字段 | owner + courseId；PDF 受保护 |
| `study_workspaces` | 计划、学习记录、证据、Wiki、智能体配置 | owner；payload 用户快照 |
| `course_review_cards` | 卡片、排程状态、评分历史 | owner + courseId |
| `course_artifacts` | 测验、闪卡、导图、对话及互动 | owner + courseId；产物课程归属固定 |
| `campus_content` | 高校信息、公共服务、课程目录、公告、活动及定向内容 | 公共记录 owner 留空；个人通知/待办指定 owner |
| `user_favorites` | 个人收藏 | owner + board + entryKey 唯一 |
| `forge_repositories` | 项目、README、GitHub 链接及审核材料 | 作者读取本人项目；公开范围受审核状态、学校与可见性约束 |
| `forge_discussions` | 项目问答、经验建议、动态、反馈及讨论状态 | 发言者 + repository，访问继承项目；社区信息流复用 |
| `forge_replies` | 讨论回复 | 发言者 + discussion，访问继承项目 |
| `forge_stars` | 项目关注 | owner + repository 唯一 |
| `forge_categories` | 分类名称、颜色、排序和 AI 整理锁定状态 | owner 私有 |
| `forge_bookmarks` | 项目分类、标签、备注、README 分析、分析时间及 GitHub 元数据 | owner + repository 唯一；category 可空且属于本人 |
| `forge_subscriptions` | 项目版本订阅、预发布选项与上次检查时间 | owner + repository 唯一 |
| `forge_release_events` | 外部版本 ID、版本内容、发布时间与已读状态 | owner + repository + externalId 唯一；subscription 属于本人且指向同一项目 |

具体字段、索引和级联行为以迁移代码为准。运营台分层视图复用这些关系，同一记录可从用户或项目上下文查看。

## 公共与个人内容

`campus_content` 的 published 控制发布，kind 区分服务、公告、活动和待办等，payload 保存对应领域数据。迁移 1790210012 增加 owner：公开记录按发布状态读取；带归属的记录按当前账号读取；个人待办要求明确归属。

服务目录中的 demo 标记属于服务端记录属性，管理员可以维护。生产客户端已移除离线演示数据替代，连接失败显示网络状态与重试入口。测试账号、可管理测试记录继续保留。

## 项目收藏与订阅

本节对应 2026-10-21 的 1.6.2，生产迁移已执行。

`1790210014_forge_library.js` 新建上表的四个收藏库集合。普通用户写入使用已验证账号，owner 固定为本人；读取和修改书签、订阅、事件时，关联项目须为本人所有，或满足华师大、已审核、学校归属已核验和公开四项条件。owner、repository 和事件的 subscription 在更新时固定。运营台位于用户工作区的“校园 GitHub → 收藏与订阅”，沿用用户筛选和 schema 动态编辑。

Star 和书签分别保存：`forge_stars` 负责关注关系及公开计数，`forge_bookmarks` 负责个人整理。取消 Star 保留书签，重新 Star 后恢复同一份整理结果。删除分类会清空书签的 category；删除订阅级联删除对应事件，书签继续保留。

分类名称上限 80 字符，颜色采用 `#RRGGBB`，position 为整数。locked 控制 AI 建议是否保留现有分类，手工修改照常。书签 tags 按字符串数组使用，JSON 字节上限 8 KiB；note 上限 4000 字符，analysis 上限 48 KiB，githubMetadata 上限 32 KiB。事件 externalId 上限 100 字符，payload 上限 96 KiB。Key 保存在本机账号分区，集合只保存资料与处理结果。

GitHub Stars 逐项导入为用户自己的私有草稿，继续使用原项目审核流程。AI 分析写入个人 bookmark；确认应用后更新本人分类和标签。版本事件由手动刷新读取 GitHub 后写入，进入页面读取已保存事件，read 字段记录个人已读状态。

## 社区交流（1.6.3，2026-10-21 开发中）

信息流复用 `forge_discussions` 与 `forge_replies`，每条交流仍通过 repository 归属原项目，回复仍通过 discussion 关联原讨论，不新增集合或迁移。频道对应现有 kind：技术问答 `question`、经验与建议 `idea`、项目动态 `update`、问题反馈 `bug`；全部视图不增加类型值。

跨项目查询限定华师大、学校归属已核验、已审核且公开的项目，结合讨论标题、正文、项目话题关键词和本人 `forge_stars` 关系过滤，在服务器排序与分页。个人草稿不进入公共信息流；讨论及回复无需预审核，项目上架审核规则继续生效。发帖需选择同一公开范围内的项目并满足现有已验证账号写入规则，内容直接进入原项目讨论。

## 计划、笔记与学习成果

以下为 2026-10-19 产品收拢后保留的历史学习数据实现。

计划使用 `study_workspaces.payload.activities`，完成时间 completedAt 控制待办/归档，恢复时清空。优先级、标签、子任务、预计用时保留在任务内。快照同步仍存在多设备后写覆盖，逐条版本冲突合并列入后续。

笔记正文上限与 Markdown 导入的 2 MB 对齐，PDF 文件上限 20 MB。受保护文件通过用户会话获取文件令牌。成果 payload 上限 512 KB，对话应用侧存档上限 450 KB；卡片评分历史保留最近 500 条。

## 迁移顺序

全新库先执行 `experiments/pocketbase/pb_migrations/` 的四个基础迁移，再执行 `deploy/pocketbase/pb_migrations/` 的生产迁移。后者为 1790210000 至 1790210014，共 15 个文件；截至 2026-10-21，生产库已执行含 `1790210014_forge_library.js` 在内的全部生产迁移。1.6.3 社区交流沿用这些结构，不增加迁移；验证记录见[验收记录](ACCEPTANCE.md)。

现有生产库备份后按增量部署手册升级，保持已执行迁移内容固定。结构检查与真实数据库执行分别验证。

## 旧 Prisma 模型

`apps/api/prisma/schema.prisma` 保存 University、User、CampusService、CampusApp、CampusAppUsage、Tag、TagAlias、TagLink、CampusAppLike，共九个模型及六个 migration。它与现网 PocketBase 是两套结构。

课程契约中的 firstPeriodStart、periodMinutes 和目录 openCount 按各自 TypeScript/Dart 模型及映射维护。旧 API 的使用量、点赞等表与当前社区集合分别演进，迁移时需要显式映射。
