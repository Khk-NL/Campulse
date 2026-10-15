# 课程知识工作台

更新：2026-10-15。以课程组织资料、笔记、提问、复习和成果。实现范围与具体设备验收分别记录。

## 使用路径

1. 打开课程，新增文字笔记，或导入 Markdown/PDF。
2. 选择资料，在全文搜索中查找原文；结果显示来源及页/行位置。
3. 提问或生成测验、闪卡、思维导图，查看回答与成果的证据引用。
4. 完成测验提交查看成绩；将闪卡加入课程复习，自评后读取下一次到期时间。
5. 在课程内创建智能体角色并连续提问，历史成果和对话按课程保存，支持现有编辑与分页入口。

## 集成与数据

网关采用 `campulse-headless`。EduWork 的 parser、tokenizer、mindmap、evidence-labels 固定来源提交为 `d1943988c44ef3dfcfe0eed54808d86b9d5a3ff3`，许可与源码位于 vendor/eduwork。`eduworkRevision` 对应这批模块的来源。

PocketBase 保存笔记原文、附件、卡片、成果、测验互动和对话；ChatECNU 负责模型生成。普通用户 token 在服务端刷新验证，资料和成果再检查 owner/courseId。智能体配置从当前用户工作台读取。

| 公开网关路由 | 用途 |
| --- | --- |
| GET /ai/v1/status | 实际可用能力与来源版本 |
| POST /ai/v1/ask | 资料问答 |
| POST /ai/v1/search | 原文检索 |
| POST /ai/v1/generate | quiz / flashcards / mindmap |
| GET /ai/v1/artifacts | 课程成果与对话分页 |
| GET /ai/v1/artifacts/:id | 单个成果 |
| POST /ai/v1/artifacts/:id/interaction | 测验作答 |
| POST /ai/v1/artifacts/:id/edit | 成果编辑 |
| POST /ai/v1/agents/ask | 连续智能体对话 |
| POST /ai/v1/cards/:id/review | FSRS 评分排程 |

字段与校验以 `apps/ai-gateway/src/server.mjs` 和 `notebook.mjs` 为准。Caddy 将 /ai 前缀剥离后转发。

## 容量与算法

Markdown 2 MB，PDF 20 MB。客户端 PDF 预览提取为有界摘录，服务端全文读取使用 unpdf；当前全文搜索采用词项匹配排序。扫描件 OCR 与向量语义检索属于后续扩展。

服务端 PDF 限制为 1500 页、100 万字符，单次最多选择 12 份资料，总文字上限 2 MB；模型读取检索片段。PDF 派生文字缓存有数量与总字符上限，原文件继续由 PocketBase 受保护存储提供。

成果历史默认每页 20 条。对话单记录存档上限 450 KB，模型读取最近 18 条；长期消息分段和归档继续扩展。卡片评分采用 ts-fsrs，历史保留 500 条。用户工作台快照的多设备并发合并仍需后续实现。

## 部署与测试

基础笔记集合之后，依次应用 PDF、卡片、成果及全文容量迁移（1790210006 至 1790210009）。使用锁文件安装网关依赖，部署顺序为备份 → 数据库增量 → 网关 → 公网双账号验证 → 云构建 APK → 设备操作。

`scripts/notebook-studio-acceptance.mjs` 覆盖检索、引用、生成、编辑、评分、连续对话与隔离。PDF 专项可用 `scripts/create-notebook-pdf-fixture.mjs` 生成测试文件后，按脚本环境变量指定文件和查询页。测试会创建并清理专用记录，需先读脚本并确认账号。

历史公网结果、MuMu 已测范围及剩余输入/提交/重启操作见[验收记录](ACCEPTANCE.md)。
