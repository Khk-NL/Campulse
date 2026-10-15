# 华东师范大学适配

更新：2026-10-15。学校信息、公共服务入口、ChatECNU 模型服务和校方统一认证分别接入。

## 当前范围

| 能力 | 当前实现 |
| --- | --- |
| 学校服务 | PocketBase 管理真实网站及用户提供的小程序入口；管理员维护发布状态 |
| ChatECNU | Node 网关服务端调用，已有真实回答及学习成果验收记录 |
| 校方 OAuth2 | TypeScript 适配器已实现授权 URL 构造及身份字段映射；换码、刷新和用户信息网络调用待开发与授权 |
| 学籍、教务课表、学校消息 | 校方接口授权与实际调用列入后续 |
| App 登录 | PocketBase 自有账号与邮箱验证 |

ChatECNU Key、Campulse 普通会话和学校 SSO 凭据是独立配置。学校归属审核当前由管理员根据项目材料核验。

## 代码边界

`adapters/ecnu/src/auth/oauth2-auth.provider.ts` 中的 createAuthorizationRequest 构造授权请求；exchangeCode、refresh、fetchProfile 抛出 ECNUNotImplementedError。revoke 当前采用本地会话处理。身份字段转换由 toStudentProfile 集中完成。

学校配置同时存在客户端的高校配置和管理员公共目录中。通用业务模块通过配置、Repository 和适配接口读取，减少学校专有逻辑在页面中的分散。

`providers/mock-services.provider.ts` 为旧 TypeScript 适配器测试目录。`mock:` 是来源标记；其中 URL 需逐条核实，测试小程序占位 ID 与现网录入的真实 ID 分开维护。生产 App 从远程目录读取服务。

## 后续接入顺序

1. 在[学校开发者平台](https://developer.ecnu.edu.cn/)确认应用申请、回调域名、授权模式、数据范围及使用要求。
2. 获批后按当前官方文档完成服务端换码、刷新与资料读取；客户端只接收 Campulse 会话。
3. 将上游字段映射为现有领域模型，保留超时、限流、请求 ID 与错误语义。
4. 验证用户身份绑定、退出、权限撤销与跨账号隔离，再接入课程等获准数据。
5. 更新公开功能说明和验收记录。

接口地址、scope 和时效以实际获批配置及当次官方文档为准。学校服务入口、品牌参考和开源代码使用按各自来源与许可管理。
