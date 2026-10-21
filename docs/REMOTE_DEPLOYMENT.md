# 远程部署

更新：2026-10-21。已有服务器采用增量升级；全新安装与现有生产库分开操作。当前部署证据见[验收记录](ACCEPTANCE.md)。

1.6.2 的收藏与项目集成使用 `deploy/update-forge.sh VERIFIED_SOURCE_DIRECTORY`，包括 0014 增量迁移、网关与运营台资源；既有依赖和环境配置保留。脚本先在独立目录运行网关测试，再创建恢复点并应用迁移。个人 GitHub/AI Key 填写及服务端可选配置见[集成指南](FORGE_INTEGRATIONS.md)。

## 现有环境

校园广场增量升级使用固定 main 提交：先核对生产已有迁移至 `1790210012_user_relationships.js`，再运行 `deploy/update-community.sh <完整提交> 1790210013_campus_square.js`。脚本停 PocketBase 后备份 pb_data 与迁移目录，执行 up 后恢复服务；其他网站和网关保持。随后升级运营台静态文件，执行 `node scripts/community-acceptance.mjs --apply` 进行独立临时账号验收并清理测试记录。凭据通过 Git 忽略的 env 提供，测试数据与正式用户分别处理。

Android 与 Windows 云构建共用公开后端配置，Windows 安装与跨端验证见[桌面与同步](DESKTOP.md)。迁移、静态管理界面、客户端 Release 按此顺序部署，实际状态记入验收文档。

阿里云共享服务器 47.100.32.82，Linux + 1Panel，实际由 Caddy 管理 80/443。PocketBase 与 AI 网关分别监听 127.0.0.1:8090、127.0.0.1:8787，systemd 单元为 campus-pocketbase、campus-ai。

| 路径 | 用途 |
| --- | --- |
| /opt/campus/pocketbase | PocketBase 二进制、pb_data、pb_migrations、pb_public |
| /opt/campus/ai-gateway | 网关源码、锁定依赖 |
| /etc/campus/ai.env | 仅服务端读取的模型与内部后端配置 |
| /opt/campus/backups | 每次增量更新的恢复点 |
| /etc/caddy/Caddyfile | 既有站点与反向代理，先核实现行路径 |

当前客户端公开地址为 `https://campus.allezafrique.cn`，网关路径为 /ai。正式域名恢复按[域名流程](DOMAIN_FILING.md)执行，迁移时保留其他网站与邮件 DNS。

## 配置归属

| 配置 | 保存位置 | 谁使用 |
| --- | --- | --- |
| PocketBase/网关公开地址 | apps/mobile/config/eduwork.production.example.json | APK |
| 微信移动应用 AppID | GitHub Secret CAMPUS_WECHAT_APP_ID | CI 编译参数与 OpenSDK |
| POCKETBASE_URL | /etc/campus/ai.env，内部 127.0.0.1:8090 | 网关 |
| CHATECNU_BASE_URL、MODEL、API_KEY | /etc/campus/ai.env | 网关 |
| DEEPSEEK_BASE_URL、MODEL、API_KEY / EDUCHAT_BASE_URL、MODEL、API_KEY | /etc/campus/ai.env，可选共享服务配置 | 项目集成网关 |
| 个人 GitHub Token、各模型 Key | 应用“GitHub 与 AI 设置”，当前账号的设备安全存储 | 按次经 HTTPS 发送到项目网关 |
| SMTP 与发件信息 | PocketBase Mail settings | 服务端发信 |
| 普通测试/管理员凭据 | 受控本地 .tools 或私有服务器配置 | 验收与维护 |

ChatECNU 默认模型和基址见 `apps/ai-gateway/.env.example`。修改共享 Key 可使用已有 `deploy/configure-ai.sh`，先检查脚本目标；共享模型 Key、SMTP Key 和 AppSecret 保存在服务端，个人模型 Key 按账号保存在设备安全存储。API Key 与服务登录密码分别取得。

Brevo SMTP 使用服务商控制台给出的 SMTP Login 和 SMTP Key，并完成发件人/域名认证；现有迁移预设 smtp-relay.brevo.com:465/TLS。最终配置以实际服务商账号为准，验证流程包括测试提交、收件、注册链接和重置链接。

## 新服务器安装

1. 选择固定源码提交，准备与安装脚本哈希一致的 PocketBase 0.40.4 Linux 包和 Node 22.23.3 运行时。
2. 阅读 `deploy/install-server.sh` 的前置目录与端口检查。它要求 /opt/campus/source、对应归档和全新数据目录。
3. 安装脚本复制四个基础迁移与全部生产迁移，递归复制官网资源，用 npm ci 安装锁定依赖，再启动两个 loopback 服务。
4. 初始化独立超级管理员，设置 SMTP、发件人、App URL 和服务端模型 Key。
5. 在既有 Caddy 中追加本站路由：/ai/* 去前缀转发 8787，其他请求转发 8090。验证配置后平滑重载，核对其他网站。
6. 完成网络检查、双普通用户隔离、真实模型调用和收件验收后发布 APK。

具体模板为 `deploy/campus-pocketbase.service.example`、`deploy/campus-ai.service.example`、`deploy/Caddyfile.example`。Caddy 模板采用通用分域名示例，现有生产是同域 /ai 路由，按实际方案配置。

## 现有实例增量更新

1. 固定完整提交，确认现网版本、可用空间、负载与恢复点。
2. 涉及 1790210010、0011、0012 的社区/用户关系升级，可用 `deploy/update-community.sh SOURCE_COMMIT MIGRATION_FILE`，按顺序逐文件执行；脚本支持的文件名以源码校验为准。
3. 知识工作台升级可用 `deploy/update-notebook.sh STAGING_ABSOLUTE_PATH`。它针对 0008/0009 迁移和整套网关更新，staging 必须包含匹配的源码、锁文件、测试与迁移。新增迁移需核对其实际覆盖范围。
4. 页面更新用 `deploy/update-public-site.sh SOURCE_COMMIT`，保留静态恢复点。
5. 检查服务与 API，再运行[验收流程](ACCEPTANCE.md)，最后安装来源一致的云构建 APK。

以上脚本各有特定用途，升级前读源码并比对实际已执行迁移。现有数据库采用备份及增量处理，保留附件、账号和业务记录。

## 发布与回滚

main 的移动端/网关相关变更触发 GitHub Android 工作流，生成并校验预览签名 APK，更新 Release 及 release 元数据。纯文档修改通常只更新仓库。

回滚先确定受影响部件。静态页面和网关可恢复对应备份；数据库恢复需先评估新增记录、附件及迁移兼容，必要时在独立目录演练。回滚范围和服务恢复结果写入验收记录。
