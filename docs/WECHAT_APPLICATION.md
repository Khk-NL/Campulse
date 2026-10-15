# 微信开放平台配置

更新：2026-10-15。当前使用 Android OpenSDK 的 WXLaunchMiniProgram。功能条件依据[官方说明](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Launching_a_Mini_Program/Launching_a_Mini_Program.html)及本项目后续客服反馈分别记录。

## 应用身份

| 项目 | 已核对值 |
| --- | --- |
| 名称 | Campulse |
| 移动应用 AppID | wx04399edac364fa8e |
| Android 包名 | cn.campus.campus_mobile |
| 预览证书 MD5 | 3b8a0599b4ce81f2f2932c8121c8b4e4 |
| 平台状态 | 移动应用审核已通过；APP 跳转小程序显示未获得 |
| 账号资质 | 最近核对为个人主体、未认证 |

上述登记与 MuMu 已安装 APK 核对一致。生产签名变更需重新提取证书摘要并同步平台。AppSecret 由服务端私有管理；OpenSDK 小程序拉起使用公开移动应用 AppID。

## 账号条件与当前阻塞

官方功能页说明应用审核通过后取得拉起能力，并说明已认证账号可跳转任意合法小程序。客服针对本项目明确：个人未认证账号仅能跳转本账号关联小程序；企业或个体工商户认证后可跳转任意合法小程序，权限自动生效。

当前四个华师大相关入口均返回 has_no_permission，目的地验收仍待完成。下一步先确定适用主体与认证条件，或测试本账号关联且已发布的小程序；条件满足后复测。

## 参数与代码

移动应用 AppID 在 GitHub Secret CAMPUS_WECHAT_APP_ID 中，由 CI 传入 Dart 编译参数；原生 register 与回调使用同一 AppID。

小程序目录使用 gh_ 原始 ID，path 空值打开首页，正式版类型为 0。小程序 wx AppID 可保存为公开元数据，实际 userName 使用 gh_ ID。[Android 示例](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Launching_a_Mini_Program/Android_Development_example.html)给出参数定义。

代码位置：Dart 的 wechat_mini_program_transport.dart、Android MainActivity.kt、wxapi/WXEntryActivity.kt。sendReq 成功只代表请求交接；验收还需确认微信打开目标首页及返回 App。

## 申请材料参考

应用简介（按平台字数限制调整）：

> Campulse 面向高校学生，提供校园服务入口、课程表、资料笔记、学习计划和 AI 学习工具，并支持学生项目展示、讨论与关注。项目经学校归属核验和审核后公开。个人学习数据通过独立账号同步，校园网站及小程序由用户主动打开。

官网目标为 https://campus.scsldr.cn；当前可用配置与域名恢复状态见[验收记录](ACCEPTANCE.md)。官网提供隐私页、运行流程图和 GitHub Release 下载链接。学校名称、标识、主体及备案按实际授权填写。

## 复测

先在微信内确认目标正式版可访问，再用同一签名 APK 逐条点击。记录设备、微信/App 版本、原始 ID、页面、反馈和返回结果。真实 Android 手机与模拟器分别填写结果。
