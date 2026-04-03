import 'dart:typed_data';

import 'dart:html' as html;

Future<String?> saveBackupFile(Uint8List bytes, String fileName) async {
  final blob = html.Blob(<dynamic>[bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..style.display = 'none'
    ..download = fileName;

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return fileName;
}
