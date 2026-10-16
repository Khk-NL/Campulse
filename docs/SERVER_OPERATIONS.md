# 服务器运维

更新：2026-10-16。安装和增量部署见[部署手册](REMOTE_DEPLOYMENT.md)，当前开放项见[验收记录](ACCEPTANCE.md)。

## 已知故障与监控

2026-10-16 架构复核后，运营台增加收到的报名与多行编辑，三项静态文件增量替换后公开读回一致；恢复点 `/opt/campus/backups/admin-review-20261016`。远程社区 25 项验收通过并清理临时数据，数据库迁移沿用 0013。PocketBase、AI、Caddy 与 atop 均 active，根分区 20% / 可用 30G；正式域名 HTTP 备案阻断与 TLS 1.2 重置仍可复现。

2026-10-16 校园广场升级：源提交 `ce0535c`，生产新增迁移 `1790210013_campus_square.js`。一致性恢复点 `/opt/campus/backups/community-20261016-095650`；运营台原件在 `/opt/campus/backups/admin-square-20261016-ce0535c`。迁移后 health 与 23 项广场远程 API 验收通过，测试生成的临时账号和记录已清理。此次只短暂停 PocketBase，其他站点、Caddy 与 AI 网关保持。

2026-10-01 整机失联，云厂商监控判断磁盘 I/O 饱和。具体高 I/O 进程尚待证据定位。重启恢复与原因定位分别处理。

历史记录确认 atop 已安装，30 秒采样、保留 7 天；日志位于 /var/log/atop/。这属于历史配置，维护时重新检查 active 与日志增长。阿里云云监控的 I/O、空间和实例可用性告警需配置有效通知渠道并测试送达。

故障期间先采集轻量指标，待负载稳定后按可疑目录和任务定向排查。全盘扫描、批量备份和构建会额外增加 I/O。

## 只读检查

```bash
uptime
free -h
df -h
df -i
cat /proc/pressure/io
sudo systemctl --failed --no-pager
sudo systemctl is-active campus-pocketbase campus-ai caddy atop
sudo journalctl -b -1 -p warning -n 100 --no-pager
```

上次启动日志取决于 journald 保留策略。安装 Docker 的服务器可补 docker stats --no-stream。采集记录时脱敏令牌、账号和个人内容。

atop 按故障日期回放对应日志，结合云监控曲线、定时任务、备份和容器活动定位峰值来源，再决定限速或错峰。

## 网络与域名

在本机仓库使用 CAMPULSE_CHECK_HOST 选择目标，运行 `node scripts/check-public-endpoint.mjs`。检查 HTTP 跳转、TLS 1.2、TLS 1.3 与 PocketBase health。App 与 Dart 仓储仍需单独验证。

历史正式域名 HTTP 被备案拦截、TLS 1.2 收到重置，临时域名可用。按[域名恢复](DOMAIN_FILING.md)核实审批及接入。局部健康页可达和完整手机同步是不同证据。

## 备份与恢复

变更前记录源码、迁移版本及恢复点。增量脚本会在短暂停止 PocketBase 时备份 SQLite 数据及附件，详读脚本覆盖范围。备份至少安排一份独立于原磁盘的副本，并演练恢复。

定期核对备份体积、剩余空间与保留策略。删除前定位具体恢复点和依赖关系。云快照用于整机恢复，应用级备份用于数据库与文件恢复。

## AI 网络

最近记录中的 ChatECNU 连接问题定位为服务器 IPv6 路由超时。campus-ai 使用 Node 的 IPv4 优先及关闭地址族自动选择参数，模板保留于 deploy/campus-ai.service.example。调整仅作用于该服务，其他网站网络保持独立。

模型超时、额度不足、账号失效与 schema 缺失分别排查；先看脱敏错误分类，再用专用测试账号重试。Key 已配置与模型实际返回分别验证。

## 维护后收尾

确认两个业务服务、Caddy 和监控正常，再检查公网登录、保存/读回、受保护附件和模型请求。更新[验收记录](ACCEPTANCE.md)中的日期与版本，最后提供剩余问题及下一步。
