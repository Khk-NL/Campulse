# 收藏、版本订阅与项目分析

更新：2026-10-21，适用于 1.6.2 及后续版本。收藏库与网关已部署；实际调用、浏览器和设备结果分开登记在[验收记录](ACCEPTANCE.md)。

## 从哪里使用

探索、个人仓库上方及“我的”都有“收藏与订阅”。项目详情的“Star 并整理”会先收藏当前项目，再打开它的整理面板；已有 Star 时显示“整理与 AI 分析”。

工作台包含三部分：

- **我的 Star**：分类、个人标签、备注、关键词搜索和排序；勾选多个项目后可批量移动分类。
- **版本订阅**：订阅所绑 GitHub 仓库的 Release，检查版本、按已读状态查看消息、打开原版说明。
- **GitHub Star**：填写个人 Token 后分页读取 GitHub 收藏，逐项选择“存入个人仓库”。

分类栏在手机上可展开或收起，宽屏采用侧栏。分类颜色与锁定状态由本人设置；锁定分类在应用 AI 建议时保留，手工整理仍可修改。取消 Star 后保留个人备注和分析，再次收藏可继续使用。

GitHub 导入建立本人的私有草稿，并加入 Campulse Star；已有本人绑定项目时复用该项目。提交华师大归属材料、独立申请并通过审核后，项目才进入公开探索。GitHub Star 和 Campulse Star 分别保存。

## 最少需要填什么

| 使用场景 | 需要填写 | 位置 |
| --- | --- | --- |
| Campulse Star、分类、标签和备注 | 普通 Campulse 账号 | 应用登录 |
| 公开 GitHub 仓库信息、Release 检查 | 绑定仓库链接；个人 Token 可提高访问额度 | 项目编辑 / 集成设置 |
| 读取自己的 GitHub Stars | 个人 GitHub Token | GitHub 与 AI 设置 |
| ChatECNU 项目分析 | 个人学校 API Key，或管理员已配置的服务额度 | 集成设置 / 服务器 |
| DeepSeek 项目分析 | DeepSeek API Key，或管理员已配置的服务额度 | 集成设置 / 服务器 |
| 自部署 EduChat | 管理员配置兼容接口地址、模型名及服务要求的 Key | 服务器 / 集成设置 |

当前站点已配置 ChatECNU 共享服务，可直接选择学校服务测试模型调用。个人 GitHub Stars 和 DeepSeek 按表中位置填写自己的 Token / Key，自部署 EduChat 先准备兼容服务地址。

个人配置入口：“我的 → 设置 → GitHub 与 AI 设置”，工作台右上角也有入口。Key 按账号保存在当前设备的安全存储，调用时经 HTTPS 发送给 Campulse 网关。个人整理、分析与版本消息保存在 PocketBase，Key 随设备配置分别管理。

Android/Windows 使用系统存储；Web 使用当前浏览器、当前站点的 WebCrypto 实现。换浏览器、换域名、清理站点数据或换设备后重新填写 Key。页面可分别清除当前账号的本机集成配置。

## 第一步：GitHub Token

1. 打开 [GitHub 个人访问令牌](https://github.com/settings/personal-access-tokens)，选择创建 fine-grained personal access token。
2. 为 Token 命名并设置期限。Repository access 选择公开仓库；在 Account permissions 中把 **Starring** 设为 **Read-only**，用于读取自己的 Stars。仓库元数据沿用只读权限，当前功能按公开项目导入。
3. 复制生成的 Token，粘贴到应用的“GitHub Token”输入框。
4. 点击“检查 GitHub”。成功时表示已通过 GitHub 实际读取个人 Star 列表，空列表也属于有效响应。
5. 点击“保存到当前设备”，进入工作台的“GitHub Star”查看分页结果。
6. 选择一个公开项目，点击“存入个人仓库”。随后在 Campulse 的“我的仓库”核对私有草稿、README、源码链接和审核状态。

接口使用 GitHub 官方 REST API，仅执行读取。权限依据见 [GitHub Stars 接口说明](https://docs.github.com/en/rest/activity/starring?apiVersion=2026-03-10#list-repositories-starred-by-the-authenticated-user)。公开仓库额度耗尽时会显示等待时间；调整 Token 或等待额度恢复后重试。私有仓库沿用其原平台权限，导入范围为公开项目。

## 第二步：选择模型服务

### 华师大 ChatECNU

1. 打开学校 [ChatECNU 开放平台](https://chat.ecnu.edu.cn/open/)，使用有访问权限的学校账号登录。
2. 在个人 API Key 管理处创建并复制 Key，具体入口与额度以学校当前控制台为准。
3. 应用中选择“ChatECNU · 华师大”，填写 Key；模型留空使用服务端默认 `ecnu-plus`。
4. 点击“测试模型调用”。这会发起一次最小 JSON 请求，成功后再保存配置。
5. 打开收藏项目，点击“AI 分析”，查看摘要、用途、上手步骤和使用限制。

官方接口为 `/open/api/v1/chat/completions`，参数见[学校开发文档](https://developer.ecnu.edu.cn/vitepress/llm/api/completions.html)。

### DeepSeek

1. 打开 [DeepSeek 开放平台](https://platform.deepseek.com/)，登录并创建 API Key，确认服务额度。
2. 应用选择“DeepSeek”，填写 Key。
3. 模型留空使用服务端默认 `deepseek-flash`；需要其他型号时填写账号当前可用的模型 ID。
4. 点击“测试模型调用”，成功后保存，再从项目面板生成分析。

截至本次核对，官方文档列出的模型为 `deepseek-flash`、`deepseek-v4-pro`。网关采用非思考模式完成结构化分析，控制输出长度；可用型号与费用以[官方 API 文档](https://api-docs.deepseek.com/)为准。

### 自部署 EduChat

[EduChat 开源模型](https://github.com/ECNU-ICALK/EduChat)与学校 ChatECNU 服务分别配置。已有 EduChat 的 OpenAI 兼容部署时，管理员在 `/etc/campus/ai.env` 设置 `EDUCHAT_BASE_URL`、`EDUCHAT_MODEL`，按服务认证要求填写 `EDUCHAT_API_KEY`。基址应是追加 `/chat/completions` 前的地址；例如服务采用 `/v1/chat/completions` 时，基址以 `/v1` 结尾。

应用选择“EduChat · 自部署兼容服务”，可填写个人 Key 和模型覆盖值。服务器负责确定目标地址，应用调用固定 Campulse 网关。模型进程、GPU 与独立部署资源由该服务提供方维护。

## 第三步：应用分析建议

AI 分析读取 Campulse 项目的名称、简介、话题和 README；绑定 GitHub 时同时读取上游元数据与 README 有界摘录。两类正文分别标识，结果注明来源、模型及分析时间，写入本人的收藏记录。纯 Campulse 项目可直接分析自身内容。

点击“应用建议”后，将建议分类和标签用于个人整理；人工锁定的分类保持原值。作者的 README、公开话题和审核状态继续由项目编辑及审核流程管理。GitHub 更新只刷新来源字段，已有个人分类、标签和备注保留。

## 第四步：版本订阅

1. 在收藏项目面板启用“版本订阅”，按需包含预发布版本。
2. 打开“版本订阅”标签，点击检查更新。网关按本人订阅分页处理，读取每个仓库最近的 Release，写入个人时间线。
3. 查看版本标签、发布时间、说明及原始链接，按需标记已读。
4. 再次刷新时，已有消息去重且保留已读状态。部分仓库失败时，成功结果仍保留，失败项目给出重试提示。
5. 取消订阅会清理该订阅对应的版本消息；Star 和个人备注独立保留。

本版在用户执行检查时获取版本，打开工作台会读取已保存消息。定时后台轮询、推送及邮件通知列入后续计划。

## 管理员配置与升级

管理员可在 `/etc/campus/ai.env` 提供共享 Key，模板见 `apps/ai-gateway/.env.example`。已有 ChatECNU Key 的实例可沿用原配置；DeepSeek 和 EduChat 按所选服务填写。修改后执行 `sudo systemctl restart campus-ai`。

既有实例升级顺序：

1. 核对固定 main 提交、磁盘空间和服务状态。
2. 准备该提交的源码快照，运行 `sudo bash deploy/update-forge.sh /绝对路径/源码快照`。脚本使用当前锁定依赖，在独立目录验证网关，停 PocketBase 创建一致备份，再执行 `1790210014_forge_library.js`。
3. 脚本升级网关和运营台资源，保留恢复点。运营台的“用户工作区 → 校园 GitHub → 收藏与订阅”可查看四个新增集合。
4. 执行普通账号的分类、标签、Star、订阅、GitHub 与真实模型检查，再部署同提交 Web 云包，安装 Android/Windows 云包。
5. 核对 Release 与在线 `version.json` 的来源提交，更新[验收记录](ACCEPTANCE.md)。

全新安装继续使用[远程部署](REMOTE_DEPLOYMENT.md)流程。管理员凭据与 Key 保存在受控配置中，验收日志只输出状态和记录标识。
