import 'dart:async';

import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config/browser_endpoints.dart';

/// 保存普通用户会话到系统安全存储，不保存密码或学校凭据。
class PocketBaseSession {
  PocketBaseSession(String baseUrl, {AuthStore? authStore})
    : client = PocketBase(baseUrl, authStore: authStore);

  static String get baseUrl =>
      browserEndpoint('/', const String.fromEnvironment('POCKETBASE_URL'));
  static PocketBaseSession? _instance;
  static PocketBaseSession? get instance => _instance;

  static Future<void> initialize() async {
    if (baseUrl.isEmpty || _instance != null) return;
    const storage = FlutterSecureStorage();
    final key = 'campulse.auth.${Uri.parse(baseUrl).host}';
    final store = AsyncAuthStore(
      initial: await storage.read(key: key),
      save: (data) => storage.write(key: key, value: data),
      clear: () => storage.delete(key: key),
    );
    final session = PocketBaseSession(baseUrl, authStore: store);
    _instance = session;
    if (!session.signedIn) {
      store.clear();
      return;
    }
    try {
      await session.client
          .collection('users')
          .authRefresh()
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // 启动时网络超时不删除仍有效的本机会话。
    } on ClientException catch (error) {
      // 网络暂不可用时保留会话；服务端拒绝才退出。
      if (error.statusCode == 401 || error.statusCode == 403) store.clear();
    }
  }

  final PocketBase client;

  bool get signedIn => client.authStore.isValid;

  Future<void> signIn(String email, String password) async {
    await client.collection('users').authWithPassword(email, password);
  }

  void signOut() => client.authStore.clear();
}
