/// 运行时配置 / runtime configuration.
///
/// 所有与部署环境相关的值都从这里读取，且只通过 `--dart-define` 覆盖，不散落在
/// widget 里。这样同一份代码可以指向前端本地、测试环境或生产后端。
///
/// Every deployment-specific value is read here, overridable only through
/// `--dart-define`, never scattered across widgets. One codebase can then point
/// at a local, test or production backend.
library;

import 'browser_endpoints.dart';

/// 不可变的应用配置 / immutable app configuration.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.appVersion,
    required this.requestTimeout,
    this.weChatAppId = '',
    this.eduWorkGatewayUrl = '',
  });

  /// 由 `--dart-define=CAMPUS_API_BASE_URL=...` 覆盖的后端地址。
  /// Backend base URL, overridable with `--dart-define=CAMPUS_API_BASE_URL=...`.
  final String apiBaseUrl;

  /// 应用版本，用于「关于」页。/ app version shown on the About screen.
  final String appVersion;

  /// 单次 HTTP 请求超时。后端不在时能快速失败并落到演示数据。
  /// Per-request HTTP timeout, so a missing backend fails fast into demo data.
  final Duration requestTimeout;

  /// 微信开放平台「移动应用」AppID；为空表示**尚未接入**小程序唤起。
  ///
  /// 它同时是那条能力的**开关**：AppID 到位、原生依赖与 `WXEntryActivity` 都接好之后，
  /// 用 `--dart-define=CAMPUS_WECHAT_APP_ID=wx...` 注入即可，代码不需要再改一处判断。
  /// 空值时客户端**如实报告"本版本尚未接入"**，绝不声称能拉起小程序。
  ///
  /// The WeChat Open Platform mobile-app AppID. Empty means mini-program launching is **not
  /// wired yet**, and it doubles as that capability's switch: once the AppID, the native
  /// dependency and the callback activity are in place, inject it with
  /// `--dart-define=CAMPUS_WECHAT_APP_ID=wx...` and no other code needs to change. While it is
  /// empty the client honestly reports "not wired in this build" rather than claiming it can.
  final String weChatAppId;

  /// Campulse 自建的移动网关地址，不是 EduWork 桌面 Host 的 RPC 地址。
  /// 只允许填写公开的 HTTPS URL；模型密钥与机构凭据不得编进 APK。
  final String eduWorkGatewayUrl;

  bool get hasEduWorkGateway => eduWorkGatewayUrl.trim().isNotEmpty;

  /// 小程序唤起是否已接入 / whether mini-program launching is really wired.
  bool get hasWeChatAppId => weChatAppId.isNotEmpty;

  static const String _defaultApiBaseUrl = 'http://127.0.0.1:3000/api';

  /// 编译期注入的取值 / values injected at compile time.
  static const String configuredApiBaseUrl = String.fromEnvironment(
    'CAMPUS_API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );

  static const String configuredAppVersion = String.fromEnvironment(
    'CAMPUS_APP_VERSION',
    defaultValue: '0.1.0',
  );

  /// 编译期注入的微信开放平台 AppID（默认空 = 未接入）。
  /// The WeChat Open Platform AppID, injected at compile time (empty = not wired).
  static const String configuredWeChatAppId = String.fromEnvironment(
    'CAMPUS_WECHAT_APP_ID',
    defaultValue: '',
  );

  static String get configuredEduWorkGatewayUrl => browserEndpoint(
    '/ai',
    const String.fromEnvironment('CAMPUS_EDUWORK_GATEWAY_URL'),
  );

  /// 默认配置。可用 `--dart-define` 覆盖任意一项。
  /// The default configuration; any field can be overridden with `--dart-define`.
  factory AppConfig.defaults() {
    return AppConfig(
      apiBaseUrl: configuredApiBaseUrl,
      appVersion: configuredAppVersion,
      requestTimeout: const Duration(seconds: 5),
      weChatAppId: configuredWeChatAppId,
      eduWorkGatewayUrl: configuredEduWorkGatewayUrl,
    );
  }

  @override
  String toString() =>
      'AppConfig(apiBaseUrl: $apiBaseUrl, weChatWired: $hasWeChatAppId, eduWorkGatewayConfigured: $hasEduWorkGateway)';
}
