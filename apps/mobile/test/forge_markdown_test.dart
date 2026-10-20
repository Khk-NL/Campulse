import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/features/apps/forge_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget surface(String data, {bool dark = false}) => MaterialApp(
    theme: dark ? CampusTheme.dark() : CampusTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ForgeMarkdown(data: data),
      ),
    ),
  );

  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  testWidgets('renders GFM headings, lists, table and copyable fenced code', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      surface('''
# 校园工具

## 使用方法

- 导入自己的项目
- [x] 准备介绍

| 功能 | 状态 |
| --- | --- |
| 地图 | 已发布 |

```dart
final answer = 42;
```
'''),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('校园工具', findRichText: true), findsOneWidget);
    expect(find.text('使用方法', findRichText: true), findsOneWidget);
    expect(find.text('地图', findRichText: true), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    await tester.ensureVisible(find.byTooltip('复制代码'));
    await tester.tap(find.byTooltip('复制代码'));
    await tester.pumpAndSettle();
    expect(copied, 'final answer = 42;\n');
    expect(find.text('代码已复制'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a web link through the existing external launcher', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      launcherChannel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        null,
      ),
    );
    await tester.pumpWidget(
      surface('[项目源码](https://github.com/Khk-NL/Campulse?tab=readme#usage)'),
    );
    await tester.tap(find.text('项目源码', findRichText: true));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'launch');
    final arguments = calls.single.arguments as Map;
    expect(
      arguments['url'],
      'https://github.com/Khk-NL/Campulse?tab=readme#usage',
    );
    expect(arguments['useWebView'], isFalse);
    expect(arguments['useSafariVC'], isFalse);
    expect(find.text('已交给浏览器打开'), findsOneWidget);
  });

  testWidgets('copy failures provide feedback and preserve the code', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard_failed');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(surface('```dart\nfinal value = 1;\n```'));
    await tester.tap(find.byTooltip('复制代码'));
    await tester.pumpAndSettle();
    expect(find.text('复制失败，请重试'), findsOneWidget);
    expect(find.text('final value = 1;\n'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provides feedback when the browser rejects a link', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      launcherChannel,
      (call) async => false,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        null,
      ),
    );
    await tester.pumpWidget(surface('[项目网站](http://example.com/project)'));
    await tester.tap(find.text('项目网站', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('请检查浏览器后重试打开链接'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('relative and other protocol links stay in the document', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      launcherChannel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        null,
      ),
    );
    await tester.pumpWidget(
      surface('''
[使用说明](docs/usage.md)

[发送邮件](mailto:campus@example.com)
'''),
    );
    await tester.tap(find.text('使用说明', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('请打开项目源码查看相对链接'), findsOneWidget);
    await tester.tap(find.text('发送邮件', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('请使用 http(s) 网页链接'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('image protocols show alt text without loading local resources', (
    tester,
  ) async {
    await tester.pumpWidget(
      surface('''
![本机图片](file:///tmp/private.png)

![内嵌图片](data:image/png;base64,AAAA)

![项目示意](images/screenshot.png)

![旧站图片](http://example.com/preview.png)
'''),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('本机图片'), findsOneWidget);
    expect(find.textContaining('内嵌图片'), findsOneWidget);
    expect(find.textContaining('项目示意'), findsOneWidget);
    expect(find.textContaining('旧站图片'), findsOneWidget);
    final placeholder = find
        .ancestor(
          of: find.textContaining('项目示意'),
          matching: find.byType(Container),
        )
        .first;
    expect(tester.getSize(placeholder).width, lessThanOrEqualTo(240));
    expect(tester.takeException(), isNull);
  });

  testWidgets('HTTPS image failures preserve their readable alt text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      surface('![校园地图预览](https://example.com/preview.png)'),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      ((image.image as ResizeImage).imageProvider as NetworkImage).url,
      'https://example.com/preview.png',
    );
    expect((image.image as ResizeImage).width, 656);
    expect(find.textContaining('校园地图预览'), findsOneWidget);
    expect(find.textContaining('图片加载失败，请稍后重试'), findsOneWidget);
    final placeholder = find
        .ancestor(
          of: find.textContaining('图片加载失败，请稍后重试'),
          matching: find.byType(Container),
        )
        .first;
    expect(tester.getSize(placeholder).width, lessThanOrEqualTo(240));
    expect(tester.takeException(), isNull);
  });

  testWidgets('image decode hints follow resized surfaces and cap at 2048', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 1400);
    addTearDown(tester.view.reset);
    const data = '![项目预览](https://example.com/large.png)';
    await tester.pumpWidget(surface(data));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Image>(find.byType(Image)).image as ResizeImage).width,
      656,
    );
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(3840, 2160);
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Image>(find.byType(Image)).image as ResizeImage).width,
      2048,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty links do nothing while anchors have a dedicated prompt', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      launcherChannel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        null,
      ),
    );
    await tester.pumpWidget(surface('[空地址]()\n\n[使用目录](#usage)'));
    await tester.tap(find.text('空地址', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    tester.widget<MarkdownBody>(find.byType(MarkdownBody)).onTapLink!(
      '空地址',
      null,
      '',
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('使用目录', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('目录链接可在项目源码中查看'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets(
    'the upstream renderer reuses parsed children on equal rebuilds',
    (tester) async {
      const data = '# 项目说明\n\n缓存正文';
      late VoidCallback rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: CampusTheme.light(),
          home: StatefulBuilder(
            builder: (context, update) {
              rebuild = () => update(() {});
              return Scaffold(body: ForgeMarkdown(data: data));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paragraphFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.textSpan?.toPlainText() == '缓存正文',
      );
      final paragraph = tester.widget<Text>(paragraphFinder);
      final style = tester
          .widget<MarkdownBody>(find.byType(MarkdownBody))
          .styleSheet;
      rebuild();
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).styleSheet,
        style,
      );
      expect(tester.widget<Text>(paragraphFinder), same(paragraph));
    },
  );

  testWidgets('image placeholders keep a finite width inside GFM tables', (
    tester,
  ) async {
    await tester.pumpWidget(
      surface('''
| 类型 | 截图 |
| --- | --- |
| 页面 | ![界面预览](assets/preview.png) |
'''),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('界面预览'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long code and tables scroll locally on a narrow dark surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.reset);
    final longCode = 'print("${'campus_' * 80}");';
    await tester.pumpWidget(
      surface('''
# 项目文档

```dart
$longCode
```

| 组件 | 项目地址 |
| --- | --- |
| Campulse | https://example.com/${'project/' * 30} |
''', dark: true),
    );
    await tester.pumpAndSettle();
    final body = tester.getRect(find.byType(MarkdownBody));
    expect(body.left, greaterThanOrEqualTo(0));
    expect(body.right, lessThanOrEqualTo(360));
    final horizontal = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((scroll) => scroll.scrollDirection == Axis.horizontal)
        .toList();
    expect(horizontal, hasLength(2));
    for (final scroll in horizontal) {
      expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
    }
    final codeScroll = find.byWidget(horizontal.first);
    await tester.drag(codeScroll, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(horizontal.first.controller!.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
