# 开源软件使用

更新：2026-10-15。下表区分运行时依赖、随仓库分发的源码和产品参考。新增依赖或复制代码时同步维护来源、版本、版权与许可。

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
| GitHubStarsManager | [源码](https://github.com/AmintaCCCP/GithubStarsManager/) | 分类、筛选与项目发现的产品参考；代码引入时另核许可及版本 |

产品参考与源码分发分别记录。当前完整依赖清单以 package.json、锁文件和 Flutter pubspec 为准；本表集中说明主要集成及参考来源。MIT 组件发行物保留版权与许可，copyleft 代码引入按其许可义务处理，第三方标识按各自使用要求处理。

## EduWork 集成语义

Campulse 使用 headless 管线，将导入模块与 PocketBase 鉴权、受保护文件、ChatECNU、成果校验和移动端组合。状态字段 eduworkRevision 表示上述核心模块的上游来源提交，integration 为 campulse-headless。

EduWork 桌面 Studio 的 DSH 宿主、工作区与进程协议属于独立部署架构。当前 HTTP 接口由 Campulse 网关提供，详见[课程知识工作台](COURSE_NOTEBOOK.md)。

dire.muedu.org/student 用于功能组织参考。Campulse 的课程、笔记和社区数据由自身数据库管理，智能体能力位于课程学习空间内。

## 维护要求

新增分发源码时记录固定提交、原始许可与本地修改。保留 vendor 目录中的 README 与 LICENSE，升级时核对模块接口并运行对应回归测试。对外展示学校服务与开源来源时使用真实名称及授权范围。
