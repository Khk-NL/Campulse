# Campulse 文档

更新：2026-10-21。Campulse 当前聚焦校园代码与项目共享，课表、通知、快速访问和校园广场作为辅助功能。产品介绍见[项目首页](../README.md)，部署和设备状态见[验收记录](ACCEPTANCE.md)。

| 读者与用途 | 入口 |
| --- | --- |
| 试用与功能操作 | [使用指南](USAGE.md) |
| 收藏、版本订阅与项目 AI | [集成与 Key 配置](FORGE_INTEGRATIONS.md) |
| 电脑安装与跨端操作 | [桌面与同步](DESKTOP.md) |
| 继续开发 | [开发指南](DEVELOPMENT.md)、[交接清单](HANDOFF.md) |
| 理解模块与数据 | [架构](ARCHITECTURE.md)、[数据模型](DATA_MODEL.md) |
| Web 开发与发布 | [浏览器工作台](WEB.md) |
| 管理用户和审核项目 | [运营台](ADMIN_CONSOLE.md)、[项目审核](PROJECT_REVIEW.md) |
| 部署、维护与域名切换 | [部署手册](REMOTE_DEPLOYMENT.md)、[运维](SERVER_OPERATIONS.md)、[域名恢复](DOMAIN_FILING.md) |
| 确认完成范围 | [验收记录](ACCEPTANCE.md)、[路线图](ROADMAP.md) |
| 设计、学校适配、微信 | [设计](DESIGN.md)、[ECNU 适配](ECNU_ADAPTER.md)、[微信配置](WECHAT_APPLICATION.md) |
| 开源与扩展契约 | [开源使用](OPEN_SOURCE_USAGE.md)、[插件契约](PLUGIN_SPEC.md) |

## 维护方式

笔记、AI 学习与复习工作台已退出客户端主流程，[课程知识工作台](COURSE_NOTEBOOK.md)保留历史实现说明。继续开发先按[交接清单](HANDOFF.md)中的当前范围执行。

同一主题维护一份固定名称的文档。实施前读相关代码，实施后更新功能范围、部署依赖和验收结果。测试数量只记录在验收文档，附执行日期；运行版本从 Release 元数据读取。

已合并的临时方案、日期清单、研究笔记和过期阶段日志已从当前目录删除。历史正文可从 Git 历史查阅；整理前的本机文档另有 Git 忽略目录中的备份。第三方源码的来源说明和许可随代码保留。
