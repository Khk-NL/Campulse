# Android 预览包

安装包统一从 [GitHub Release](https://github.com/Khk-NL/Campulse/releases/tag/campulse-preview)下载。本目录维护下载说明；GitHub Actions 构建并上传 APK、来源元数据和校验文件。

当前版本与来源以 [Campulse-latest.json](https://github.com/Khk-NL/Campulse/releases/download/campulse-preview/Campulse-latest.json) 为准，文件 SHA-256 见 [校验文件](https://github.com/Khk-NL/Campulse/releases/download/campulse-preview/Campulse-latest.apk.sha256)。安装前核对 sourceCommit，设备版本与云构建源码分别确认。

## 构建与签名

main 的移动端、网关或 Android 工作流相关修改触发云端检查、Flutter 构建和稳定预览签名校验；纯文档修改通常只更新仓库。版本代码为 1000 + GitHub 构建序号。

Android 包名 cn.campus.campus_mobile。预览证书 MD5 为 3b8a0599b4ce81f2f2932c8121c8b4e4，属于证书摘要；APK 文件哈希使用单独的 SHA-256 校验文件。预览证书与正式生产签名分别管理，变更签名时同步核对微信平台登记和升级安装兼容。

## 产物与历史

源码分支保留产品代码与说明，安装包发布到 Releases。构建任务上传后直接完成，避免二进制提交与 main 更新发生冲突。曾随仓库提交的旧预览包可从 Git 历史取回，日常测试使用最新元数据对应安装包。

功能与设备验收见[验收记录](../docs/ACCEPTANCE.md)，发布过程见[部署手册](../docs/REMOTE_DEPLOYMENT.md)。
