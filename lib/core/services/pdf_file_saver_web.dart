// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:typed_data';

import 'dart:html' as html;

Future<String?> savePdfFile(Uint8List bytes, String fileName) async {
  final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
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