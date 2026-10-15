# 插件契约

更新：2026-10-15。packages/plugin-runtime 与 packages/campus-sdk 保存 manifest、权限、桥接、生命周期及回滚契约。插件宿主和加载执行属于后续开发范围；当前校园服务及项目社区按现有 Launcher 与网页入口运行。

## 包与清单

包内由 manifest.json、入口 HTML 和资源组成。清单字段以 packages/plugin-runtime 源码为准：

- id：kebab-case，与插件业务标识对应。
- name、version、entry：名称、语义版本及包内相对入口。
- permissions：申请的权限集合，用户实际同意的权限独立保存。
- description、icon、repository、minRuntimeVersion：可选元数据。

入口校验限制为包内相对路径，检查目录穿越、绝对路径、盘符及外部 URL。原生二进制执行由策略类型限制。兼容与回滚沿用源码主版本规则。

## 权限与桥接

现有权限契约包括 user.basic、course.read、todo.read/write、calendar.read/write、notification.request、service.open。桥接方法映射集中在 BRIDGE_METHOD_PERMISSION，checkBridgeCall 按实际授予权限校验。

运行时实现需提供独立存储 origin、网络域策略、桥接白名单和崩溃隔离。生命周期显式记录运行与崩溃状态；权限申请、授予、撤销和升级分别验证。

## 实施前检查

先验证当前项目分发与使用需求，再确定宿主容器。新增运行时需补集成测试、权限撤销、隔离、来源验证和回滚演练。校园项目上架继续使用[项目审核](PROJECT_REVIEW.md)；插件运行授权作为独立环节实现。
