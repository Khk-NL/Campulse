# 开源软件使用

更新：2026-10-21。下表区分运行时依赖、随仓库分发的源码和产品参考。新增依赖或复制代码时同步维护来源、版本、版权与许可。

| 项目 | 来源与许可 | 使用范围 |
| --- | --- | --- |
| Study Courses & Timetable | [sp-study-courses](https://github.com/Khk-NL/sp-study-courses)，MIT | 参考课程导入、教学周、冲突和去重；Campulse 使用 Dart 实现及节次模型 |
| EduWork | [固定源码提交](https://github.com/ECNU/EduWork/tree/d1943988c44ef3dfcfe0eed54808d86b9d5a3ff3/packages/dsh-knowledge-studio)，MIT | 导入 parser、tokenizer、mindmap、evidence-labels 四个核心模块；源码与许可位于网关 vendor/eduwork |
| Open Notebook | [源码](https://github.com/lfnovo/open-notebook)，MIT | 参考资料、笔记、问答和学习成果的组织方式 |
| ts-fsrs | [源码](https://github.com/open-spaced-repetition/ts-fsrs)，MIT | 网关运行时依赖，用于云端复习排程；实际版本以 package-lock.json 为准 |
| Anki | [源码与许可](https://github.com/ankitects/anki/blob/main/LICENSE)，AGPL-3.0-or-later | 产品参考：正反面、自评与待复习队列；代码分发范围按 AGPL 许可单独评估 |
| file_picker / pdfrx | [file_picker](https://pub.dev/packages/file_picker)、[pdfrx](https://pub.dev/packages/pdfrx)，MIT | Flutter 文件选择与 PDF 阅读 |
| unpdf | [源码](https://github.com/unjs/unpdf)，MIT | 网关 PDF 全文提取，锁定版本与完整性哈希保存在 package-lock.json |
| Super Productivity | [源码](https://github.com/super-productivity/super-productivity)，MIT | 参考任务归档/恢复、截止日期、子任务和预计用时 |
| flutter_markdown_plus | [源码](https://github.com/foresightmobile/flutter_markdown_plus)，BSD-3-Clause | 运行时依赖，锁定 1.0.12；用于项目 README、讨论及编辑预览，保留 Flutter Authors 原版权与许可 |
| markdown | [源码](https://github.com/dart-lang/markdown)，BSD-3-Clause | 直接依赖，锁定 7.3.1；用于 Markdown 代码节点识别，保留 Dart project authors 原版权与许可 |
| GitHubStarsManager | [源码](https://github.com/AmintaCCCP/GithubStarsManager/)，MIT | 参考收藏组织、分类筛选和 GitHub 集成的产品及实现思路；1.6.2 的相关代码由 Campulse 自行实现 |
| GitHub / Hugging Face Hub | [Issue 筛选](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/filtering-and-searching-issues-and-pull-requests)、[Hub Community](https://huggingface.co/docs/hub/repositories-pull-requests-discussions) | 项目概览、Markdown、议题分类与处理流程的设计参考；取舍见[界面设计](DESIGN.md) |
| CSDN 社区 / 论坛 | [社区](https://community.csdn.net/)、[论坛](https://bbs.csdn.net/)官方页面，2026-10-21 观察 | 1.6.3 社区交流的频道、时间线、项目/社区来源、全文与回复组织参考；不抓取内容、不引入其源码或新依赖 |

产品参考与源码分发分别记录。当前完整依赖清单以 package.json、锁文件和 Flutter pubspec 为准；本表集中说明主要集成及参考来源。MIT 组件发行物保留版权与许可，copyleft 代码引入按其许可义务处理，第三方标识按各自使用要求处理。

2026-10-20 的 1.6.1 加入 Markdown 组件，封装界面样式、代码复制和外链处理，渲染及语法解析交给上述两个 BSD 依赖。发行物随 Flutter 依赖许可材料保留其版权、三项条件和免责声明，源码依赖版本以 `apps/mobile/pubspec.lock` 为准。

2026-10-21 的 1.6.2 收藏库、GitHub 只读集成与项目分析已实现并部署，沿用现有 Flutter、HTTP 客户端和 Node.js 依赖。Campulse 的 Star、整理和分析结果保存在自身数据库；用户选择的 GitHub Stars 按项目导入为个人私有草稿，GitHub 侧维持只读访问。真实连接范围和验证结果统一见[验收记录](ACCEPTANCE.md)。

同日开发的 `1.6.3+12` 社区交流在现有项目讨论、回复、Star 与 Markdown 流程内实现，不新增依赖或迁移。CSDN 仅作信息组织与交互参考，Campulse 的帖子继续关联已审核华师大公开项目，不扩展为独立博客平台。

## EduWork 集成语义

Campulse 使用 headless 管线，将导入模块与 PocketBase 鉴权、受保护文件、ChatECNU、成果校验和移动端组合。状态字段 eduworkRevision 表示上述核心模块的上游来源提交，integration 为 campulse-headless。

EduWork 桌面 Studio 的 DSH 宿主、工作区与进程协议属于独立部署架构。当前 HTTP 接口由 Campulse 网关提供，详见[课程知识工作台](COURSE_NOTEBOOK.md)。

dire.muedu.org/student 用于原课程学习空间的功能组织参考。Campulse 的课程、笔记和社区数据由自身数据库管理，相关学习页面按历史实现保留。

## 维护要求

校园广场的产品组织参考复旦[旦挞](https://github.com/DanXi-Dev/DanXi)、[求是潮手机站](https://www.qsc.zju.edu.cn/mobile)与[航概校园邦](https://github.com/Fewing/buaa_takeaway)，交互和数据访问在现有 Campulse 架构内实现。旦挞和校园邦仓库标注 GPL-3.0，后续源码集成按原许可单独评估；当前登记为设计参考。

新增分发源码时记录固定提交、原始许可与本地修改。保留 vendor 目录中的 README 与 LICENSE，升级时核对模块接口并运行对应回归测试。对外展示学校服务与开源来源时使用真实名称及授权范围。
