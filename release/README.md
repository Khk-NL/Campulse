# Android 预览包

从 [GitHub Release](https://github.com/Khk-NL/Campulse/releases/tag/campulse-preview)下载，或使用本目录的 [Campulse-latest.apk](Campulse-latest.apk)。

当前版本与来源以 [Campulse-latest.json](Campulse-latest.json) 为准，文件 SHA-256 见 [校验文件](Campulse-latest.apk.sha256)。安装前核对 sourceCommit，设备版本与云构建源码分别确认。

## 构建与签名

main 的移动端、网关或 Android 工作流相关修改触发云端检查、Flutter 构建和稳定预览签名校验；纯文档修改通常只更新仓库。版本代码为 1000 + GitHub 构建序号。

Android 包名 cn.campus.campus_mobile。预览证书 MD5 为 3b8a0599b4ce81f2f2932c8121c8b4e4，属于证书摘要；APK 文件哈希使用单独的 SHA-256 校验文件。预览证书与正式生产签名分别管理，变更签名时同步核对微信平台登记和升级安装兼容。

## 旧资产

目录中的 Campus-1.0.0 预览包作为旧资产保留；日常测试使用最新元数据对应安装包。当前工作流仍维护仓库中的二进制，产物存储优化列入后续工程维护。

功能与设备验收见[验收记录](../docs/ACCEPTANCE.md)，发布过程见[部署手册](../docs/REMOTE_DEPLOYMENT.md)。
