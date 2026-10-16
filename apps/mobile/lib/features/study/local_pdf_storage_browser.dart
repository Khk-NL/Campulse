import 'dart:typed_data';

// The browser product stores PDF attachments through the authenticated cloud repository.
Future<String> writePdf(String id, Uint8List bytes) async =>
    throw UnsupportedError('请登录云端账号后导入 PDF');
Future<Uint8List> readPdf(String filePath) async =>
    throw UnsupportedError('请从云端资料库打开 PDF');
Future<void> deletePdf(String filePath) async =>
    throw UnsupportedError('请从云端资料库管理 PDF');
