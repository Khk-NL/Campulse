import 'package:campus_mobile/core/launcher/external_opener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Project README and discussion prose, with local scrolling for wide content.
class ForgeMarkdown extends StatelessWidget {
  const ForgeMarkdown({super.key, required this.data});

  final String data;

  static bool _isWebAddress(Uri? uri) =>
      uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;

  Future<void> _openLink(BuildContext context, String? href) async {
    final address = href?.trim() ?? '';
    if (address.isEmpty) return;
    if (address.startsWith('#')) {
      _message(context, '目录链接可在项目源码中查看');
      return;
    }
    final uri = Uri.tryParse(address);
    if (uri != null && !uri.hasScheme) {
      _message(context, '请打开项目源码查看相对链接');
      return;
    }
    if (!_isWebAddress(uri)) {
      _message(context, '请使用 http(s) 网页链接');
      return;
    }
    final opened = await openUrlExternally(uri!);
    if (context.mounted) {
      _message(context, opened ? '已交给浏览器打开' : '请检查浏览器后重试打开链接');
    }
  }

  Widget _image(Uri uri, String? alt, double maxWidth, double pixelRatio) {
    final label = alt?.trim().isNotEmpty == true ? alt!.trim() : '项目图片';
    final placeholderWidth = maxWidth.clamp(0, 240).toDouble();
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      return SizedBox(
        width: placeholderWidth,
        child: _ImageFallback(label: label, detail: '请打开项目源码查看图片'),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 420),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          uri.toString(),
          cacheWidth: (maxWidth * pixelRatio).ceil().clamp(1, 2048),
          fit: BoxFit.contain,
          semanticLabel: label,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: placeholderWidth,
            child: _ImageFallback(label: label, detail: '图片加载失败，请稍后重试'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => SelectionArea(
        child: MarkdownBody(
          // The renderer caches its parsed children. Recreate only when image
          // layout inputs change so decoded image widths follow window resizing.
          key: ValueKey((constraints.maxWidth, pixelRatio)),
          data: data,
          onTapLink: (_, href, _) => _openLink(context, href),
          imageBuilder: (uri, title, alt) => _image(
            uri,
            alt,
            constraints.maxWidth.isFinite ? constraints.maxWidth : 600,
            pixelRatio,
          ),
          builders: {'pre': _CodeBlockBuilder()},
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: text.bodyMedium?.copyWith(height: 1.65),
            h1: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            h2: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            h3: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            h4: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            a: TextStyle(
              color: colors.primary,
              decoration: TextDecoration.underline,
              decorationColor: colors.primary.withValues(alpha: .5),
            ),
            code: text.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colors.primaryContainer.withValues(alpha: .35),
            ),
            blockSpacing: 16,
            listIndent: 24,
            blockquotePadding: const EdgeInsets.all(14),
            blockquoteDecoration: BoxDecoration(
              color: colors.tertiaryContainer.withValues(alpha: .25),
              border: Border(
                left: BorderSide(color: colors.tertiary, width: 3),
              ),
            ),
            codeblockDecoration: const BoxDecoration(),
            tableColumnWidth: const IntrinsicColumnWidth(),
            tableScrollbarThumbVisibility: true,
            tableHead: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            tableBorder: TableBorder.all(color: colors.outlineVariant),
            tableHeadCellsDecoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .25),
            ),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
          ),
        ),
      ),
    );
  }
}

void _message(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(text)));
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.label, required this.detail});
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.image_outlined),
        const SizedBox(width: 10),
        Expanded(child: Text('$label\n$detail')),
      ],
    ),
  );
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final language = code?.attributes['class']?.replaceFirst('language-', '');
    return _CodeBlock(code: element.textContent, language: language);
  }
}

class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.code, this.language});
  final String code;
  final String? language;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      if (mounted) _message(context, '代码已复制');
    } on Exception {
      if (mounted) _message(context, '复制失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.language?.isNotEmpty == true
                        ? widget.language!
                        : '代码',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                IconButton(
                  tooltip: '复制代码',
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                ),
              ],
            ),
          ),
          Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
              child: Text(
                widget.code,
                softWrap: false,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
