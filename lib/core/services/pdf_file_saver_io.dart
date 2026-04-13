import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> savePdfFile(Uint8List bytes, String fileName) async {
  final savedPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Export note as PDF',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    bytes: bytes,
  );

  if (savedPath == null || savedPath.trim().isEmpty) {
    return null;
  }

  return savedPath;
}