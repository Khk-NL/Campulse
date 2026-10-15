# 正式域名恢复

更新：2026-10-15。目标域名 campus.scsldr.cn，当前 APK 配置仍为 campus.allezafrique.cn。这里记录恢复流程，审批进度以云控制台当前状态为准。

## 最近证据

2026-10-09 至 10-10 的记录显示：DNS 指向 47.100.32.82，正式域名 HTTP 命中阿里云备案拦截，外部 TLS 1.2 重置，TLS 1.3 曾能访问健康接口。临时域名 TLS 1.2/1.3 与 health 通过。

10-09 阿里云订单已提交并处于初审。这是当时状态，本轮文档整理沿用待确认标记。

## 审批与接入

通过[阿里云备案控制台](https://beian.aliyun.com/pcContainer/myorder)确认订单、补正、短信核验及审核结果。历史申请使用现有主体新增服务，域名在腾讯云注册并由 DNSPod 解析，服务器为阿里云内地实例。

证件、短信及人脸核验在官方页面完成。服务介绍与实际开放的账号、资料同步、校园服务和项目社区一致；最终材料按当次审核要求提交。保留其他网站和 Brevo 邮件 DNS 记录。

## 恢复顺序

1. 核对备案通过及接入状态，再检查目标 DNS 和 Caddy 路由。
2. 设置 CAMPULSE_CHECK_HOST=campus.scsldr.cn，运行 `node scripts/check-public-endpoint.mjs`；HTTP、TLS 1.2/1.3 和 health 全部通过。
3. 在实际设备验证正式域名的账号、笔记同步、PDF 与 AI/复习访问。
4. 同步修改 apps/mobile/config/eduwork.production.example.json 中 PocketBase 与网关地址。
5. 使用 `scripts/remote-acceptance.mjs --set-app-url` 更新 PocketBase meta.appURL；目标通过 CAMPULSE_APP_URL 指定。脚本读取私有管理员配置并只允许已知两个域名。
6. 执行配置检查、双账号验收和验证/重置邮件链接检查。
7. 推送 main，核对云构建 sourceCommit 后安装 APK，复测点击与重启恢复。

临时域名停用时间应覆盖旧版 App 更新周期和已发送邮件链接，先确认使用情况再调整。最终入口与恢复证据同步写入[验收记录](ACCEPTANCE.md)、README 及内部运营收藏。
