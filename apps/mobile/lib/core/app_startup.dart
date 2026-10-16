/// 启动装配 / application bootstrap.
///
/// 装配顺序刻意保持"先探测、后渲染"：`main()` 里先问一次 `/api/health`，把结果作为
/// 初始数据源模式交给仓库。这样第一帧就能显示正确的离线横幅，不会先闪一个"加载中"
/// 再跳到"离线"。探测失败不会阻塞启动，超时是 [AppConfig.requestTimeout]。
///
/// The order is deliberately "probe, then render": `main()` asks `/api/health` once and
/// hands the result to the repository as its initial mode, so the very first frame shows
/// the right offline banner instead of flashing a spinner. A failed probe never blocks
/// startup; the timeout is [AppConfig.requestTimeout].
library;

import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/core/launcher/wechat_mini_program_transport.dart';
import 'package:campus_mobile/data/http/campus_api_client.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/pocketbase_campus_repository.dart';
import 'package:campus_mobile/data/repositories/remote_campus_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一次完整的启动结果 / the complete result of one startup.
class AppBootstrap {
  const AppBootstrap({
    required this.state,
    required this.config,
    this.weChatMiniPrograms,
  });

  /// 装配好的应用状态 / the assembled app state.
  final AppState state;

  /// 本次运行使用的配置 / the configuration this run uses.
  final AppConfig config;

  /// 小程序传输：仅在配置了微信 AppID 时存在；注册没通过时它的 `isWired` 为 false。
  ///
  /// 这里刻意保留"已注册但注册失败"的对象，而不是失败时返回 null：界面需要能分清
  /// "本次构建没有配 AppID"与"配了但被微信拒绝"——后者通常意味着 AppID 类型不对或
  /// 包名/签名与开放平台不一致，是要拿去修的东西。
  ///
  /// The mini-program transport, present only when a WeChat AppID is configured; its `isWired`
  /// is false when registration was refused. It is deliberately kept rather than nulled on
  /// failure: the UI must tell "this build has no AppID" apart from "we have one and WeChat
  /// refused it", the latter meaning the AppID type or the package/signature is wrong.
  final OpenSdkMiniProgramTransport? weChatMiniPrograms;
}

/// 装配整个 App / assemble the whole app.
class AppStartup {
  const AppStartup._();

  /// 构建应用状态。`preferences` 无法初始化时自动降级为内存偏好。
  /// Build the app state, silently degrading to in-memory preferences when the platform
  /// store cannot be opened.
  static Future<AppBootstrap> bootstrap({AppConfig? config}) async {
    final AppConfig resolved = config ?? AppConfig.defaults();
    await PocketBaseSession.initialize();
    final CampusRepository repository;
    final PocketBaseSession? pilot = PocketBaseSession.instance;
    if (pilot != null) {
      final PocketBaseCampusRepository pocketBase = PocketBaseCampusRepository(
        client: pilot.client,
      );
      await pocketBase.probe();
      repository = pocketBase;
    } else {
      final CampusApiClient apiClient = CampusApiClient(config: resolved);
      final RemoteCampusRepository remote = RemoteCampusRepository(
        apiClient: apiClient,
      );
      await remote.probe();
      repository = remote;
    }

    final PreferenceStore preferences =
        await PreferenceStore.open() ?? await _inMemoryPreferences();

    final AppState state = AppState(
      repository: repository,
      config: resolved,
      preferences: preferences,
      initialLocale: _localeFromCode(preferences.readLanguageCode()),
      initialThemeMode: preferences.readThemeMode(),
    );
    await state.loadIdentity();
    return AppBootstrap(
      state: state,
      config: resolved,
      weChatMiniPrograms: await _weChatMiniPrograms(resolved),
    );
  }

  /// 配置了微信 AppID 时注册一次 / register once when a WeChat AppID is configured.
  ///
  /// 注册失败**不是启动错误**：它只意味着"小程序唤起这一条能力当前不可用"，应用照常可用，
  /// 由界面如实说明原因。因此这里不做任何重试，也不抛出。
  /// A refused registration is not a startup failure: it only means that one capability is
  /// unavailable, the app still works, and the UI explains why. No retries, no throwing.
  static Future<OpenSdkMiniProgramTransport?> _weChatMiniPrograms(
    AppConfig config,
  ) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !config.hasWeChatAppId) {
      return null;
    }
    final OpenSdkMiniProgramTransport transport = OpenSdkMiniProgramTransport(
      appId: config.weChatAppId,
    );
    await transport.register();
    return transport;
  }

  /// 探测后端；任何失败都只是"离线"，不是错误。
  /// Probe the backend; every failure simply means "offline", not an error.

  /// 存储不可用时的兜底：用 shared_preferences 自带的内存实现，App 依然可用
  /// （只是不记忆用户选择）。
  /// Fallback when platform storage is unavailable: shared_preferences' own in-memory
  /// implementation, so the app still works but forgets the user's choices.
  static Future<PreferenceStore> _inMemoryPreferences() async {
    // 这个 API 被标注为"仅供测试"，但在 platform 实现缺失时它恰好能装出一个可用的
    // 内存实现，因此这里是有意为之，并显式忽略告警：宁可让用户的选择不被记住，
    // 也不要让整个 App 起不来。
    // The API is annotated test-only, but it happens to install a usable in-memory
    // implementation when the platform one is missing, so this is deliberate and the
    // warning is acknowledged: losing the user's choices beats failing to start.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return PreferenceStore(await SharedPreferences.getInstance());
  }

  /// 语言代码 → Locale；未知或空值返回 null（跟随系统）。
  /// Language code to Locale; null for empty or unknown values, meaning "follow system".
  static Locale? _localeFromCode(String? code) {
    switch (code) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        return null;
    }
  }
}
