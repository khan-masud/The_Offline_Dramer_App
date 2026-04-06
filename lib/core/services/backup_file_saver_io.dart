import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveBackupFile(Uint8List bytes, String fileName) async {
  final savedPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Select where to save backup',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['todbackup'],
    bytes: bytes,
  );

  if (savedPath == null || savedPath.trim().isEmpty) {
    return null;
  }

  return savedPath;
}
