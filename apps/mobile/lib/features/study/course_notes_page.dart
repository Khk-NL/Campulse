import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:campus_mobile/features/study/pdf_text_extraction.dart';
import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:campus_mobile/features/study/review_cards_page.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseNotesPage extends StatefulWidget {
  const CourseNotesPage({
    super.key,
    required this.courseId,
    required this.repository,
    this.reviewCardRepository,
  });

  final String courseId;
  final CourseNoteRepository repository;
  final ReviewCardRepository? reviewCardRepository;

  @override
  State<CourseNotesPage> createState() => _CourseNotesPageState();
}

class _CourseNotesPageState extends State<CourseNotesPage> {
  bool _importing = false;
  String _query = '';
  int _kind = 0;
  late Future<List<CourseNote>> _notes = widget.repository.list(
    widget.courseId,
  );

  void _reload() => setState(() {
    _notes = widget.repository.list(widget.courseId);
  });

  Future<void> _openCards([CourseNote? note]) async {
    final ReviewCardRepository cards =
        widget.reviewCardRepository ??
        LocalReviewCardRepository(await SharedPreferences.getInstance());
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ReviewCardsPage(
          courseId: widget.courseId,
          repository: cards,
          noteId: note?.id ?? '',
          initialFront: note?.title ?? '',
          initialBack: note?.content ?? '',
        ),
      ),
    );
  }

  Future<void> _import() async {
    if (_importing) return;
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['md', 'markdown', 'pdf'],
    );
    if (file == null || !mounted) return;
    final String extension = path.extension(file.name).toLowerCase();
    final int limit = extension == '.pdf' ? 20 * 1024 * 1024 : 2 * 1024 * 1024;
    if ((file.lengthSync() ?? await file.length() ?? limit + 1) > limit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            extension == '.pdf' ? 'PDF 最大支持 20 MB' : 'Markdown 最大支持 2 MB',
          ),
        ),
      );
      return;
    }
    setState(() => _importing = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      if (extension == '.pdf') {
        if (bytes.length < 4 || ascii.decode(bytes.sublist(0, 4)) != '%PDF') {
          throw const FormatException('PDF 格式校验失败，请重新选择文件');
        }
        String excerpt = '';
        try {
          excerpt = await extractPdfExcerpt(bytes);
        } on Exception {
          // Keep the original PDF usable when it is scanned or extraction fails.
        }
        await widget.repository.importPdf(
          widget.courseId,
          file.name,
          bytes,
          extractedText: excerpt,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                excerpt.isEmpty
                    ? 'PDF 已导入，可阅读原文件；AI 提问需要包含可提取文字的资料'
                    : 'PDF 已导入；已提取部分文字供课程提问使用',
              ),
            ),
          );
        }
      } else {
        final String content = utf8
            .decode(bytes, allowMalformed: false)
            .replaceFirst('\uFEFF', '');
        await widget.repository.save(
          CourseNote(
            id: '',
            courseId: widget.courseId,
            title: path.basenameWithoutExtension(file.name),
            content: content,
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (mounted) _reload();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openPdf(CourseNote note) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            _PdfNotePage(note: note, repository: widget.repository),
      ),
    );
  }

  Future<void> _edit([CourseNote? note]) async {
    final CourseNote? result = await Navigator.of(context).push<CourseNote>(
      MaterialPageRoute<CourseNote>(
        builder: (BuildContext context) => _NoteEditor(
          courseId: widget.courseId,
          note: note,
          repository: widget.repository,
        ),
      ),
    );
    if (result != null && mounted) _reload();
  }

  Future<void> _delete(CourseNote note) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除笔记？'),
        content: Text('“${note.title}”将被永久删除，请先备份需要保留的内容。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.delete(note.id);
      if (mounted) _reload();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('课程笔记'),
      actions: <Widget>[
        IconButton(
          tooltip: '复习卡片',
          onPressed: () => _openCards(),
          icon: const Icon(Icons.style_outlined),
        ),
        TextButton.icon(
          onPressed: _importing ? null : _import,
          icon: const Icon(Icons.file_upload_outlined),
          label: Text(_importing ? '导入中…' : '导入 PDF / MD'),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('新建笔记'),
    ),
    body: FutureBuilder<List<CourseNote>>(
      future: _notes,
      builder: (BuildContext context, AsyncSnapshot<List<CourseNote>> snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('笔记加载失败，点击重试'),
            ),
          );
        }
        final allNotes = snapshot.data!;
        final List<CourseNote> notes =
            allNotes
                .where(
                  (note) =>
                      (_kind == 0 ||
                          (_kind == 1 ? note.hasPdf : !note.hasPdf)) &&
                      '${note.title} ${note.content}'.toLowerCase().contains(
                        _query.toLowerCase(),
                      ),
                )
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _notes;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
            itemCount: notes.length + 1,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WorkspaceBanner(
                        eyebrow: 'COURSE COLLECTION',
                        title: '资料与笔记',
                        subtitle: '教材、课堂摘录和自己的思考，集中整理。',
                        icon: Icons.auto_stories_outlined,
                      ),
                      const SizedBox(height: 12),
                      WorkspaceGrid(
                        minWidth: 170,
                        children: [
                          WorkspaceMetric(
                            value:
                                '${allNotes.where((note) => note.hasPdf).length}',
                            label: 'PDF 教材',
                            icon: Icons.picture_as_pdf_outlined,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          WorkspaceMetric(
                            value:
                                '${allNotes.where((note) => !note.hasPdf).length}',
                            label: '文字笔记',
                            icon: Icons.edit_note_rounded,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: '查找资料',
                          hintText: '搜索标题或正文…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in const {
                            0: '全部资料',
                            1: 'PDF 教材',
                            2: '文字笔记',
                          }.entries)
                            ChoiceChip(
                              showCheckmark: false,
                              label: Text(entry.value),
                              selected: _kind == entry.key,
                              onSelected: (_) =>
                                  setState(() => _kind = entry.key),
                            ),
                        ],
                      ),
                      if (notes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            allNotes.isEmpty ? '导入教材或新建笔记' : '试试其他关键词或资料类型',
                          ),
                        ),
                    ],
                  ),
                );
              }
              final CourseNote note = notes[index - 1];
              return TweenAnimationBuilder<double>(
                key: ValueKey<String>(note.id),
                tween: Tween<double>(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                builder: (BuildContext context, double value, Widget? child) =>
                    Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - value)),
                        child: child,
                      ),
                    ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      title: Text(note.title),
                      subtitle: Text(
                        '${note.hasPdf ? 'PDF 教材' : '文字笔记'} · ${MaterialLocalizations.of(context).formatCompactDate(note.updatedAt.toLocal())}\n${note.content}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: note.hasPdf
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : Theme.of(context).colorScheme.secondaryContainer,
                        child: Icon(
                          note.hasPdf
                              ? Icons.picture_as_pdf_outlined
                              : Icons.description_outlined,
                        ),
                      ),
                      onTap: () => note.hasPdf ? _openPdf(note) : _edit(note),
                      trailing: PopupMenuButton<String>(
                        onSelected: (String action) {
                          if (action == 'card') {
                            _openCards(note);
                          }
                          if (action == 'delete') {
                            _delete(note);
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'card',
                                child: Text('制作复习卡片'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('删除笔记'),
                              ),
                            ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class _PdfNotePage extends StatefulWidget {
  const _PdfNotePage({required this.note, required this.repository});
  final CourseNote note;
  final CourseNoteRepository repository;

  @override
  State<_PdfNotePage> createState() => _PdfNotePageState();
}

class _PdfNotePageState extends State<_PdfNotePage> {
  late final Future<Uint8List> _bytes = widget.repository.readPdf(widget.note);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.note.title)),
    body: FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('PDF 打开失败：${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfViewer.data(snapshot.data!, sourceName: widget.note.id);
      },
    ),
  );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    required this.courseId,
    required this.repository,
    this.note,
  });

  final String courseId;
  final CourseNoteRepository repository;
  final CourseNote? note;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.note?.title,
  );
  late final TextEditingController _content = TextEditingController(
    text: widget.note?.content,
  );
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final CourseNote note = CourseNote(
        id: widget.note?.id ?? '',
        courseId: widget.courseId,
        title: _title.text.trim(),
        content: _content.text.trim(),
        updatedAt: DateTime.now(),
        attachment: widget.note?.attachment ?? '',
        localFile: widget.note?.localFile ?? '',
      );
      final CourseNote saved = await widget.repository.save(note);
      if (mounted) Navigator.pop(context, saved);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请检查网络后重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.note == null ? '新建笔记' : '编辑笔记'),
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '标题 *'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _content,
              decoration: const InputDecoration(
                labelText: '笔记正文',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ],
      ),
    ),
  );
}
