import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/config/university_config.dart';
import '../../core/pocketbase_session.dart';
import '../../core/launcher/external_opener.dart';

/// Personal credentials stay on this device, scoped to the signed-in account.
class ForgeIntegrationSettings {
  const ForgeIntegrationSettings({
    this.githubToken = '',
    this.provider = ProjectAiProviders.school,
    this._aiKey,
    this._model,
    this.providerKeys = const {},
    this.providerModels = const {},
  });

  static const providers = ProjectAiProviders.ids;
  final String githubToken;
  final String provider;
  final String? _aiKey;
  final String? _model;
  final Map<String, String> providerKeys;
  final Map<String, String> providerModels;
  String get aiKey => _aiKey ?? providerKeys[provider] ?? '';
  String get model => _model ?? providerModels[provider] ?? '';

  ForgeIntegrationSettings copyWith({
    String? githubToken,
    String? provider,
    String? aiKey,
    String? model,
  }) => ForgeIntegrationSettings(
    githubToken: githubToken ?? this.githubToken,
    provider: provider ?? this.provider,
    aiKey: aiKey,
    model: model,
    providerKeys: {...providerKeys, this.provider: this.aiKey},
    providerModels: {...providerModels, this.provider: this.model},
  );

  Map<String, dynamic> toJson() => {
    'githubToken': githubToken.trim(),
    'provider': provider,
    'providerKeys': {...providerKeys, provider: aiKey.trim()},
    'providerModels': {...providerModels, provider: model.trim()},
  };

  factory ForgeIntegrationSettings.fromJson(Map<String, dynamic> json) {
    Map<String, String> strings(Object? value) => value is Map
        ? {
            for (final entry in value.entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: entry.value as String,
          }
        : {};
    return ForgeIntegrationSettings(
      githubToken: json['githubToken'] is String ? json['githubToken'] : '',
      provider: providers.contains(json['provider'])
          ? json['provider']
          : ProjectAiProviders.school,
      providerKeys: strings(json['providerKeys']),
      providerModels: strings(json['providerModels']),
    );
  }

  void validate() {
    if (!providers.contains(provider)) throw StateError('请选择模型服务');
    for (final value in [githubToken, aiKey, ...providerKeys.values]) {
      if (value.length > 1024 ||
          RegExp(r'\s').hasMatch(value.trim()) ||
          RegExp(r'[\x00-\x1F]').hasMatch(value)) {
        throw StateError('请填写完整的单行 Key');
      }
    }
    for (final value in [model, ...providerModels.values]) {
      if (value.isNotEmpty &&
          !RegExp(r'^[A-Za-z0-9_.:/-]{1,100}$').hasMatch(value)) {
        throw StateError('模型名称请使用 100 字符以内的字母、数字或 . _ : / -');
      }
    }
  }
}

class ForgeIntegrationStore {
  ForgeIntegrationStore({
    this._namespace,
    FlutterSecureStorage? storage,
    this._read,
    this._write,
    this._remove,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final String? _namespace;
  final FlutterSecureStorage _storage;
  final Future<String?> Function(String)? _read;
  final Future<void> Function(String, String)? _write;
  final Future<void> Function(String)? _remove;

  String get _key {
    if (_namespace != null) return 'campulse.forge.integrations.$_namespace';
    final session = PocketBaseSession.instance;
    final id = session?.client.authStore.record?.id ?? '';
    if (session?.signedIn != true || id.isEmpty) {
      throw StateError('请登录后设置集成服务');
    }
    return 'campulse.forge.integrations.${Uri.parse(session!.client.baseURL).origin}.$id';
  }

  Future<ForgeIntegrationSettings> load() async {
    final key = _key;
    final raw = _read == null
        ? await _storage.read(key: key)
        : await _read(key);
    if (raw == null || raw.isEmpty) return const ForgeIntegrationSettings();
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('集成设置读取失败，请重新保存');
    }
    return ForgeIntegrationSettings.fromJson(data);
  }

  Future<void> save(ForgeIntegrationSettings settings) async {
    settings.validate();
    final key = _key;
    final value = jsonEncode(settings.toJson());
    if (_write != null) {
      await _write(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<void> clear() async {
    final key = _key;
    if (_remove != null) {
      await _remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }
}

class ForgeGatewayException implements Exception {
  const ForgeGatewayException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class ForgeGateway {
  ForgeGateway({required this.baseUrl, required this.token, this.client});
  final String baseUrl;
  final String token;
  final http.Client? client;

  Future<Map<String, dynamic>> _send(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final base = Uri.tryParse(baseUrl.trim());
    final local =
        base != null &&
        base.scheme == 'http' &&
        (kDebugMode || (kIsWeb && base.origin == Uri.base.origin)) &&
        ['127.0.0.1', 'localhost', '10.0.2.2'].contains(base.host);
    if (base == null ||
        base.host.isEmpty ||
        (base.scheme != 'https' && !local) ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const ForgeGatewayException('请配置 HTTPS 集成网关地址', 0);
    }
    if (token.isEmpty) throw const ForgeGatewayException('请登录后使用集成服务', 401);
    final uri = base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}/v1/forge/$path',
    );
    final connection = client ?? http.Client();
    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
      final http.Response response;
      if (body == null) {
        response = await connection
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
      } else {
        response = await connection
            .post(
              uri,
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 90));
      }
      if (response.bodyBytes.length > 2 * 1024 * 1024) {
        throw const ForgeGatewayException('响应内容较大，请缩小查询范围', 502);
      }
      final Object? data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const ForgeGatewayException('服务响应格式有误，请稍后重试', 502);
      }
      if (response.statusCode != 200) {
        final message = data is Map && data['error'] is String
            ? (data['error'] as String).characters.take(300).toString()
            : '服务连接失败，请稍后重试';
        throw ForgeGatewayException(message, response.statusCode);
      }
      if (data is! Map<String, dynamic>) {
        throw const ForgeGatewayException('服务响应格式有误，请稍后重试', 502);
      }
      return data;
    } on TimeoutException {
      throw const ForgeGatewayException('服务响应超时，请稍后重试', 504);
    } on http.ClientException {
      throw const ForgeGatewayException('连接中断，请检查网络后重试', 0);
    } finally {
      if (client == null) connection.close();
    }
  }

  Map<String, dynamic> _credentials(
    ForgeIntegrationSettings settings, {
    bool ai = false,
  }) {
    settings.validate();
    return {
      if (settings.githubToken.trim().isNotEmpty)
        'githubToken': settings.githubToken.trim(),
      if (ai) 'provider': settings.provider,
      if (ai && settings.aiKey.trim().isNotEmpty)
        'apiKey': settings.aiKey.trim(),
      if (ai && settings.model.trim().isNotEmpty)
        'model': settings.model.trim(),
    };
  }

  Future<Map<String, dynamic>> status() => _send('status');
  Future<Map<String, dynamic>> github(
    String repositoryId,
    ForgeIntegrationSettings settings,
  ) => _send('github', {
    ..._credentials(settings),
    'repositoryId': repositoryId,
  });
  Future<Map<String, dynamic>> analyze(
    String repositoryId,
    ForgeIntegrationSettings settings,
  ) => _send('analyze', {
    ..._credentials(settings, ai: true),
    'repositoryId': repositoryId,
  });
  Future<Map<String, dynamic>> refreshReleases(
    ForgeIntegrationSettings settings, {
    String? repositoryId,
    int page = 1,
  }) => _send('releases/refresh', {
    ..._credentials(settings),
    'repositoryId': ?repositoryId,
    'page': page,
  });
  Future<Map<String, dynamic>> githubStars(
    ForgeIntegrationSettings settings, {
    int page = 1,
  }) => _send('github/stars', {..._credentials(settings), 'page': page});
  Future<Map<String, dynamic>> importGithub(
    String fullName,
    ForgeIntegrationSettings settings,
  ) =>
      _send('github/import', {..._credentials(settings), 'fullName': fullName});
  Future<Map<String, dynamic>> check(ForgeIntegrationSettings settings) =>
      _send('check', _credentials(settings, ai: true));
}

Future<bool> showForgeIntegrationSettings(
  BuildContext context, {
  ForgeIntegrationStore? store,
  ForgeGateway? gateway,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _ForgeIntegrationPage(
        store: store ?? ForgeIntegrationStore(),
        gateway: gateway,
      ),
    ),
  );
  return saved == true;
}

class _ForgeIntegrationPage extends StatefulWidget {
  const _ForgeIntegrationPage({required this.store, this.gateway});
  final ForgeIntegrationStore store;
  final ForgeGateway? gateway;
  @override
  State<_ForgeIntegrationPage> createState() => _ForgeIntegrationPageState();
}

class _ForgeIntegrationPageState extends State<_ForgeIntegrationPage> {
  final github = TextEditingController();
  final ai = TextEditingController();
  final model = TextEditingController();
  ForgeIntegrationSettings settings = const ForgeIntegrationSettings();
  Map<String, dynamic>? service;
  bool loading = true, busy = false, revealGithub = false, revealAi = false;
  String? message;
  ForgeGateway? get gateway =>
      widget.gateway ??
      (PocketBaseSession.instance == null
          ? null
          : ForgeGateway(
              baseUrl: AppConfig.configuredEduWorkGatewayUrl,
              token: PocketBaseSession.instance!.client.authStore.token,
            ));

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.store.load();
      if (!mounted) return;
      settings = value;
      github.text = value.githubToken;
      ai.text = value.aiKey;
      model.text = value.model;
    } on StateError catch (error) {
      if (mounted) message = error.message.toString();
    } on FormatException {
      if (mounted) message = '集成设置读取失败，请重新保存';
    } catch (_) {
      if (mounted) message = '设备安全存储读取失败，请检查浏览器权限后重试';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  ForgeIntegrationSettings get current => settings.copyWith(
    githubToken: github.text.trim(),
    aiKey: ai.text.trim(),
    model: model.text.trim(),
  );

  Future<void> action(Future<String> Function() run) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final text = await run();
      if (mounted) setState(() => message = text);
    } on ForgeGatewayException catch (error) {
      if (mounted) setState(() => message = error.message);
    } on StateError catch (error) {
      if (mounted) setState(() => message = error.message.toString());
    } catch (_) {
      if (mounted) setState(() => message = '设置处理失败，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> link(String value) async {
    final success = await openUrlExternally(Uri.parse(value));
    if (!success && mounted) setState(() => message = '请检查浏览器后重试打开链接');
  }

  @override
  void dispose() {
    github.dispose();
    ai.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final providerInfo = service?['providers'];
    final info = providerInfo is Map ? providerInfo[settings.provider] : null;
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub 与 AI 设置')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '连接你的开发工具',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '分类、收藏和订阅使用 Campulse 账号。个人 Key 保存在当前设备，并随调用发送至集成网关；换设备后可重新填写。',
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.code),
                                title: Text('GitHub'),
                                subtitle: Text(
                                  '公开仓库可直接读取；个人 Star 导入使用自己的 Token。',
                                ),
                              ),
                              TextField(
                                controller: github,
                                obscureText: !revealGithub,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: 'GitHub Token（选填）',
                                  suffixIcon: IconButton(
                                    tooltip: revealGithub
                                        ? '隐藏 GitHub Token'
                                        : '显示 GitHub Token',
                                    onPressed: () => setState(
                                      () => revealGithub = !revealGithub,
                                    ),
                                    icon: Icon(
                                      revealGithub
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                '建议创建仅访问公开仓库的只读 Token，供个人 Star 列表和仓库信息查询使用。',
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => link(
                                      'https://github.com/settings/personal-access-tokens',
                                    ),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('创建 GitHub Token'),
                                  ),
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => action(() async {
                                            if (gateway == null) {
                                              throw StateError('请登录后检查连接');
                                            }
                                            if (github.text.trim().isEmpty) {
                                              throw StateError(
                                                '填写 Token 后可检查个人 Star',
                                              );
                                            }
                                            await gateway!.githubStars(current);
                                            return 'GitHub 连接成功，个人 Star 可读取';
                                          }),
                                    child: const Text('检查 GitHub'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.auto_awesome),
                                title: Text('项目 AI 分析'),
                                subtitle: Text('生成用途、上手建议与个人分类建议。'),
                              ),
                              DropdownButtonFormField<String>(
                                key: ValueKey(settings.provider),
                                initialValue: settings.provider,
                                decoration: const InputDecoration(
                                  labelText: '模型服务',
                                ),
                                items: [
                                  for (final entry
                                      in ProjectAiProviders.labels.entries)
                                    DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                ],
                                onChanged: busy
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setState(() {
                                          settings = current.copyWith(
                                            provider: value,
                                          );
                                          ai.text = settings.aiKey;
                                          model.text = settings.model;
                                        });
                                      },
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: ai,
                                obscureText: !revealAi,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: 'AI Key（个人选填）',
                                  helperText: '留空时使用管理员为该服务配置的额度',
                                  suffixIcon: IconButton(
                                    tooltip: revealAi
                                        ? '隐藏 AI Key'
                                        : '显示 AI Key',
                                    onPressed: () =>
                                        setState(() => revealAi = !revealAi),
                                    icon: Icon(
                                      revealAi
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: model,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  labelText: '模型名称（选填）',
                                  helperText: '留空时采用服务端默认模型',
                                ),
                              ),
                              if (settings.provider == 'educhat')
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(ProjectAiProviders.schoolHelp),
                                ),
                              if (info is Map)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    '服务模型：${info['model'] ?? '由服务器提供'} · ${info['configured'] == true ? '服务端已配置' : '可填写个人 Key'}',
                                  ),
                                ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => link(
                                      ProjectAiProviders.helpUrls[settings
                                          .provider]!,
                                    ),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('服务与 Key 说明'),
                                  ),
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => action(() async {
                                            if (gateway == null) {
                                              throw StateError('请登录后读取服务配置');
                                            }
                                            final data = await gateway!
                                                .status();
                                            if (mounted) {
                                              setState(() => service = data);
                                            }
                                            return '服务配置已读取，实际分析时会验证所选凭据';
                                          }),
                                    child: const Text('读取服务配置'),
                                  ),
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => action(() async {
                                            if (gateway == null) {
                                              throw StateError('请登录后测试模型');
                                            }
                                            final snapshot = current;
                                            final result = await gateway!.check(
                                              snapshot,
                                            );
                                            return '模型调用成功：${result['model'] ?? snapshot.provider}';
                                          }),
                                    child: const Text('测试模型调用'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            message!,
                            style: TextStyle(color: colors.primary),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => action(() async {
                                await widget.store.save(current);
                                if (context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                                return '设置已保存';
                              }),
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('保存到当前设备'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => action(() async {
                                await widget.store.clear();
                                if (!mounted) return '配置已清除';
                                settings = const ForgeIntegrationSettings();
                                github.clear();
                                ai.clear();
                                model.clear();
                                return '当前账号在此设备上的 Key 已清除';
                              }),
                        child: const Text('清除本机集成配置'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
