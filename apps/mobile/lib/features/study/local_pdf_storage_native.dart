import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String> writePdf(String id, Uint8List bytes) async {
  final directory = Directory(
    path.join((await getApplicationDocumentsDirectory()).path, 'course-pdfs'),
  );
  await directory.create(recursive: true);
  final file = File(path.join(directory.path, '$id.pdf'));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List> readPdf(String filePath) => File(filePath).readAsBytes();

Future<void> deletePdf(String filePath) async {
  final file = File(filePath);
  if (await file.exists()) await file.delete();
}
