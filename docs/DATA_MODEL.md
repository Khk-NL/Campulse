# 数据模型与归属

更新：2026-10-15。现网业务数据库为 PocketBase（内置 SQLite）。集合结构由基础迁移与生产迁移共同定义；Prisma schema 属于旧 API 实现。

## 业务层级

```text
用户
 ├─ 学习
 │   ├─ 课程 → 笔记 / PDF、复习卡片、学习成果
 │   ├─ 课程表（同一批课程的时间视图）
 │   └─ 计划、学习过程、个人通知与待办
 ├─ 校园 GitHub
 │   ├─ 个人仓库 → 收到的讨论与回复
 │   └─ 社区项目 → 参与的讨论与回复、Star
 ├─ 校园广场 → 个人召集 / 报名意向 / 活动讨论 / 兴趣名片
 └─ 收藏 → 引用公共服务或入口

公共目录
 ├─ 官方小程序与官网
 └─ 校园公告与活动
```

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
| `forge_discussions` | 项目问题、建议和讨论状态 | 发言者 + repository，访问继承项目 |
| `forge_replies` | 讨论回复 | 发言者 + discussion，访问继承项目 |
| `forge_stars` | 项目关注 | owner + repository 唯一 |

具体字段、索引和级联行为以迁移代码为准。运营台分层视图复用这些关系，同一记录可从用户或项目上下文查看。

## 公共与个人内容

`campus_content` 的 published 控制发布，kind 区分服务、公告、活动和待办等，payload 保存对应领域数据。迁移 1790210012 增加 owner：公开记录按发布状态读取；带归属的记录按当前账号读取；个人待办要求明确归属。

服务目录中的 demo 标记属于服务端记录属性，管理员可以维护。生产客户端已移除离线演示数据替代，连接失败显示网络状态与重试入口。测试账号、可管理测试记录继续保留。

## 计划、笔记与学习成果

计划使用 `study_workspaces.payload.activities`，完成时间 completedAt 控制待办/归档，恢复时清空。优先级、标签、子任务、预计用时保留在任务内。快照同步仍存在多设备后写覆盖，逐条版本冲突合并列入后续。

笔记正文上限与 Markdown 导入的 2 MB 对齐，PDF 文件上限 20 MB。受保护文件通过用户会话获取文件令牌。成果 payload 上限 512 KB，对话应用侧存档上限 450 KB；卡片评分历史保留最近 500 条。

## 迁移顺序

全新库先执行 `experiments/pocketbase/pb_migrations/` 的四个基础迁移，再执行 `deploy/pocketbase/pb_migrations/` 的生产迁移。后者当前为 1790210000 至 1790210012，共 13 个文件。

现有生产库备份后按增量部署手册升级，保持已执行迁移内容固定。结构检查与真实数据库执行分别验证。

## 旧 Prisma 模型

`apps/api/prisma/schema.prisma` 保存 University、User、CampusService、CampusApp、CampusAppUsage、Tag、TagAlias、TagLink、CampusAppLike，共九个模型及六个 migration。它与现网 PocketBase 是两套结构。

课程契约中的 firstPeriodStart、periodMinutes 和目录 openCount 按各自 TypeScript/Dart 模型及映射维护。旧 API 的使用量、点赞等表与当前社区集合分别演进，迁移时需要显式映射。
