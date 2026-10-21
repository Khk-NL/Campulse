import 'dart:async';
import 'dart:convert';

import 'package:campus_mobile/features/apps/forge_integrations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'provider switching preserves separate keys, models and explicit clearing',
    () {
      var settings = const ForgeIntegrationSettings(
        githubToken: 'github-fixture',
        aiKey: 'campus-fixture',
        model: 'ecnu-plus',
      );
      settings = settings
          .copyWith(provider: 'deepseek')
          .copyWith(aiKey: 'deepseek-fixture', model: 'deepseek-flash');
      expect(settings.copyWith(provider: 'chatecnu').aiKey, 'campus-fixture');
      expect(settings.copyWith(provider: 'chatecnu').model, 'ecnu-plus');
      final saved = ForgeIntegrationSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())),
      );
      expect(saved.aiKey, 'deepseek-fixture');
      expect(saved.copyWith(provider: 'chatecnu').aiKey, 'campus-fixture');
      expect(saved.copyWith(aiKey: '').aiKey, '');
      expect(
        saved.copyWith(aiKey: '').copyWith(provider: 'chatecnu').aiKey,
        'campus-fixture',
      );
    },
  );

  test(
    'credentials reject header control characters and invalid providers',
    () {
      expect(
        () => const ForgeIntegrationSettings(aiKey: 'value\nheader').validate(),
        throwsStateError,
      );
      expect(
        () => const ForgeIntegrationSettings(provider: 'unknown').validate(),
        throwsStateError,
      );
      expect(
        () => ForgeIntegrationSettings(model: 'x' * 121).validate(),
        throwsStateError,
      );
      expect(
        () => ForgeIntegrationSettings(aiKey: 'x' * 1025).validate(),
        throwsStateError,
      );
      expect(
        () =>
            const ForgeIntegrationSettings(aiKey: 'key with space').validate(),
        throwsStateError,
      );
      expect(
        () => ForgeIntegrationSettings(model: 'x' * 101).validate(),
        throwsStateError,
      );
      expect(
        () => const ForgeIntegrationSettings(model: 'bad model').validate(),
        throwsStateError,
      );
    },
  );

  test('secure stores isolate accounts and retain settings until explicitly cleared', () async {
    final memory = <String, String>{};
    ForgeIntegrationStore store(String owner) => ForgeIntegrationStore(
      namespace: 'https://campus.example.$owner',
      read: (key) async => memory[key],
      write: (key, value) async {
        memory[key] = value;
      },
      remove: (key) async {
        memory.remove(key);
      },
    );
    await store('a')
        .save(const ForgeIntegrationSettings(githubToken: 'fixture-token'));
    expect((await store('a').load()).githubToken, 'fixture-token');
    expect((await store('b').load()).githubToken, '');
    await store('a').clear();
    expect((await store('a').load()).githubToken, '');
  });

  test(
    'gateway keeps credentials in authenticated POST body to the fixed gateway',
    () async {
      final requests = <http.Request>[];
      final gateway = ForgeGateway(
        baseUrl: 'https://campus.example/ai',
        token: 'test-session',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );
      const settings = ForgeIntegrationSettings(
        githubToken: 'github-fixture',
        aiKey: 'ai-fixture',
        provider: 'deepseek',
      );
      await gateway.analyze('repository12345', settings);
      final request = requests.single;
      expect(
        request.url.toString(),
        'https://campus.example/ai/v1/forge/analyze',
      );
      expect(request.url.hasQuery, isFalse);
      expect(request.headers['Authorization'], 'Bearer test-session');
      expect(jsonDecode(request.body), {
        'githubToken': 'github-fixture',
        'apiKey': 'ai-fixture',
        'provider': 'deepseek',
        'repositoryId': 'repository12345',
      });
      await gateway.githubStars(settings, page: 3);
      expect(jsonDecode(requests.last.body)['page'], 3);
      expect(jsonDecode(requests.last.body).containsKey('apiKey'), isFalse);
      await gateway.refreshReleases(settings, page: 2);
      expect(jsonDecode(requests.last.body)['page'], 2);
      await gateway.importGithub('Khk-NL/Campulse', settings);
      expect(jsonDecode(requests.last.body)['fullName'], 'Khk-NL/Campulse');
    },
  );

  test(
    'gateway handles HTTP rejection, invalid response, timeout and unsafe URLs',
    () async {
      ForgeGateway response(String data, int status) => ForgeGateway(
        baseUrl: 'https://campus.example/ai',
        token: 'test-session',
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(data),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await expectLater(
        response('{"error":"请检查服务额度"}', 429).status(),
        throwsA(
          isA<ForgeGatewayException>().having(
            (e) => e.statusCode,
            'status',
            429,
          ),
        ),
      );
      await expectLater(
        response('<html>upstream</html>', 502).status(),
        throwsA(isA<ForgeGatewayException>()),
      );
      await expectLater(
        response('[]', 200).status(),
        throwsA(isA<ForgeGatewayException>()),
      );
      await expectLater(
        ForgeGateway(
          baseUrl: 'http://remote.example/ai',
          token: 'test-session',
        ).status(),
        throwsA(isA<ForgeGatewayException>()),
      );
      await expectLater(
        ForgeGateway(
          baseUrl: 'https://user:secret@campus.example/ai',
          token: 'test-session',
        ).status(),
        throwsA(isA<ForgeGatewayException>()),
      );
      await expectLater(
        ForgeGateway(baseUrl: 'https://campus.example/ai', token: '').status(),
        throwsA(isA<ForgeGatewayException>()),
      );
    },
  );

  testWidgets(
    'settings switch providers and save the configured account store',
    (tester) async {
      final memory = <String, String>{};
      final store = ForgeIntegrationStore(
        namespace: 'settings-test',
        read: (key) async => memory[key],
        write: (key, value) async {
          memory[key] = value;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showForgeIntegrationSettings(context, store: store),
                child: const Text('打开集成设置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开集成设置'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'GitHub Token（选填）'),
        'github-test',
      );
      final provider = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(provider);
      await tester.tap(provider);
      await tester.pumpAndSettle();
      await tester.tap(find.text('DeepSeek').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'AI Key（个人选填）'),
        'deepseek-test',
      );
      await tester.ensureVisible(find.text('保存到当前设备'));
      await tester.tap(find.text('保存到当前设备'));
      await tester.pumpAndSettle();
      final settings = await store.load();
      expect(settings.provider, 'deepseek');
      expect(settings.aiKey, 'deepseek-test');
      expect(settings.githubToken, 'github-test');
      expect(find.text('打开集成设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving settings during secure deletion releases controllers safely',
    (tester) async {
      final pending = Completer<void>();
      final store = ForgeIntegrationStore(
        namespace: 'late-clear',
        read: (_) async => null,
        remove: (_) => pending.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showForgeIntegrationSettings(context, store: store),
                child: const Text('打开设置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开设置'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('清除本机集成配置'));
      await tester.tap(find.text('清除本机集成配置'));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late model checks use the captured settings after leaving the page',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final store = ForgeIntegrationStore(
        namespace: 'late-model',
        read: (_) async => null,
      );
      final gateway = _DelayedModelGateway(pending);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showForgeIntegrationSettings(
                  context,
                  store: store,
                  gateway: gateway,
                ),
                child: const Text('打开设置'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开设置'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('测试模型调用'));
      await tester.tap(find.text('测试模型调用'));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      pending.complete({'ok': true});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _DelayedModelGateway extends ForgeGateway {
  _DelayedModelGateway(this.pending)
    : super(baseUrl: 'https://campus.example/ai', token: 'fixture');
  final Completer<Map<String, dynamic>> pending;
  @override
  Future<Map<String, dynamic>> check(ForgeIntegrationSettings settings) =>
      pending.future;
}
