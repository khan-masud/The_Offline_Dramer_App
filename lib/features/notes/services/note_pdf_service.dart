import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/database/app_database.dart';

class NotePdfService {
  NotePdfService._();

  /// Generates a rich, beautifully formatted PDF document for a note.
  static Future<Uint8List> generatePdf(Note note) async {
    final pdf = pw.Document(
      title: note.title.trim().isEmpty ? 'Note' : note.title.trim(),
      author: 'Me++',
    );

    final contentWidgets = await _parseContentToPdfWidgets(note.content);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (context) => _buildPdfHeader(note, context),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          _buildNoteTitleSection(note),
          pw.SizedBox(height: 12),
          ...contentWidgets,
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfHeader(Note note, pw.Context context) {
    if (context.pageNumber == 1) {
      return pw.SizedBox.shrink();
    }
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
      ),
      child: pw.Text(
        note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim(),
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.grey600,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Created with Me++',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNoteTitleSection(Note note) {
    final title = note.title.trim().isEmpty ? 'Untitled Note' : note.title.trim();
    final updatedText = DateFormat('dd MMM yyyy, hh:mm a').format(note.updatedAt);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text(
              'Updated: $updatedText',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            if (note.folder != null && note.folder!.isNotEmpty) ...[
              pw.SizedBox(width: 12),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
                ),
                child: pw.Text(
                  'Folder: ${note.folder!}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey700),
                ),
              ),
            ],
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(thickness: 1.2, color: PdfColors.blueGrey200),
      ],
    );
  }

  static Future<List<pw.Widget>> _parseContentToPdfWidgets(String content) async {
    final widgets = <pw.Widget>[];
    final lines = content.split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Empty line
      if (trimmed.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        i++;
        continue;
      }

      // Horizontal Rule
      if (RegExp(r'^(?:---|\*\*\*|___)\s*$').hasMatch(trimmed)) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(thickness: 0.8, color: PdfColors.grey400),
          ),
        );
        i++;
        continue;
      }

      // Headings: # H1, ## H2, ### H3, etc.
      final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!.trim();
        widgets.add(_buildHeadingWidget(level, text));
        i++;
        continue;
      }

      // Code Block: ```lang ... ```
      if (trimmed.startsWith('```')) {
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length && lines[i].trim().startsWith('```')) {
          i++;
        }
        widgets.add(_buildCodeBlockWidget(codeLines.join('\n')));
        continue;
      }

      // Table: | Col 1 | Col 2 |
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|') && lines[i].trim().endsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }
        final tableWidget = _buildTableWidget(tableLines);
        if (tableWidget != null) {
          widgets.add(tableWidget);
        }
        continue;
      }

      // Image: ![alt](uri)
      final imageMatch = RegExp(r'^!\[([^\]]*)\]\(([^\)]+)\)$').firstMatch(trimmed);
      if (imageMatch != null) {
        final alt = imageMatch.group(1) ?? 'Image';
        final uriStr = imageMatch.group(2) ?? '';
        final imgWidget = await _buildImageWidget(uriStr, alt);
        widgets.add(imgWidget);
        i++;
        continue;
      }

      // Checklist / Task: - [ ] or - [x]
      final taskMatch = RegExp(r'^(\s*)- \[( |x)\]\s+(.+)$').firstMatch(line);
      if (taskMatch != null) {
        final isChecked = taskMatch.group(2) == 'x';
        final taskText = taskMatch.group(3) ?? '';
        widgets.add(_buildChecklistWidget(isChecked, taskText));
        i++;
        continue;
      }

      // Bullet list: - or *
      final bulletMatch = RegExp(r'^(\s*)[-*+]\s+(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        final bulletText = bulletMatch.group(2) ?? '';
        final indentLevel = (bulletMatch.group(1)?.length ?? 0) ~/ 2;
        widgets.add(_buildBulletListWidget(bulletText, indentLevel));
        i++;
        continue;
      }

      // Numbered list: 1. 2. etc.
      final numberMatch = RegExp(r'^(\s*)(\d+)\.\s+(.+)$').firstMatch(line);
      if (numberMatch != null) {
        final numStr = numberMatch.group(2) ?? '1';
        final numText = numberMatch.group(3) ?? '';
        final indentLevel = (numberMatch.group(1)?.length ?? 0) ~/ 2;
        widgets.add(_buildNumberedListWidget(numStr, numText, indentLevel));
        i++;
        continue;
      }

      // Blockquote: > text
      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quoteLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        widgets.add(_buildBlockquoteWidget(quoteLines.join(' ')));
        continue;
      }

      // Toggle block: :::toggle Title ... :::
      if (trimmed.startsWith(':::toggle')) {
        final toggleTitle = trimmed.replaceFirst(':::toggle', '').trim();
        final bodyLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith(':::')) {
          bodyLines.add(lines[i]);
          i++;
        }
        if (i < lines.length && lines[i].trim().startsWith(':::')) {
          i++;
        }
        widgets.add(_buildToggleWidget(toggleTitle, bodyLines.join('\n')));
        continue;
      }

      // Regular paragraph
      widgets.add(_buildParagraphWidget(line));
      i++;
    }

    return widgets;
  }

  static pw.Widget _buildHeadingWidget(int level, String text) {
    double fontSize = 16;
    PdfColor color = PdfColors.blueGrey900;
    PdfColor barColor = PdfColors.blue700;
    double topMargin = 12;

    switch (level) {
      case 1:
        fontSize = 18;
        color = PdfColors.blue900;
        barColor = PdfColors.blue700;
        topMargin = 14;
        break;
      case 2:
        fontSize = 15;
        color = PdfColors.teal900;
        barColor = PdfColors.teal700;
        topMargin = 12;
        break;
      case 3:
        fontSize = 13;
        color = PdfColors.orange900;
        barColor = PdfColors.orange700;
        topMargin = 10;
        break;
      default:
        fontSize = 12;
        color = PdfColors.blueGrey800;
        barColor = PdfColors.blueGrey600;
        topMargin = 8;
    }

    return pw.Container(
      margin: pw.EdgeInsets.only(top: topMargin, bottom: 6),
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: barColor.luminance > 0.5 ? PdfColors.grey100 : PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(left: pw.BorderSide(color: barColor, width: 3.5)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCodeBlockWidget(String code) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
      ),
      child: pw.Text(
        code,
        style: pw.TextStyle(
          font: pw.Font.courier(),
          fontSize: 9.5,
          color: PdfColors.grey900,
          lineSpacing: 2,
        ),
      ),
    );
  }

  static pw.Widget? _buildTableWidget(List<String> lines) {
    if (lines.isEmpty) return null;

    final parsedRows = <List<String>>[];
    for (final line in lines) {
      // Skip markdown separator row | --- | --- |
      if (RegExp(r'^[\|\s\-\:\;]+$').hasMatch(line)) continue;

      final cells = line
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();

      if (cells.isNotEmpty) {
        parsedRows.add(cells);
      }
    }

    if (parsedRows.isEmpty) return null;

    final isFirstRowHeader = lines.length > 1 && RegExp(r'^[\|\s\-\:\;]+$').hasMatch(lines[1]);
    final headerRow = isFirstRowHeader ? parsedRows.first : null;
    final dataRows = isFirstRowHeader ? parsedRows.sublist(1) : parsedRows;

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
        children: [
          if (headerRow != null)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
              children: headerRow.map((cell) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(
                    cell,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                );
              }).toList(),
            ),
          ...dataRows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final row = entry.value;
            final isEven = rowIndex % 2 == 0;

            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: isEven ? PdfColors.white : PdfColors.grey50,
              ),
              children: row.map((cell) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: pw.RichText(
                    text: _parseInlineMarkdown(cell, baseFontSize: 9.5),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  static Future<pw.Widget> _buildImageWidget(String uriStr, String alt) async {
    try {
      Uint8List? imageBytes;

      if (uriStr.startsWith('file://')) {
        final filePath = Uri.parse(uriStr).toFilePath();
        final file = File(filePath);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      } else {
        final file = File(uriStr);
        if (await file.exists()) {
          imageBytes = await file.readAsBytes();
        }
      }

      if (imageBytes != null && imageBytes.isNotEmpty) {
        final image = pw.MemoryImage(imageBytes);
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          alignment: pw.Alignment.centerLeft,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.ConstrainedBox(
                  constraints: const pw.BoxConstraints(maxHeight: 260, maxWidth: 460),
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
              if (alt.isNotEmpty && alt.toLowerCase() != 'image') ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  alt,
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('PDF Image parse error: $e');
    }

    // Fallback if image could not be loaded
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('[Image: $alt]', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _buildChecklistWidget(bool isChecked, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 11,
            height: 11,
            margin: const pw.EdgeInsets.only(top: 2, right: 6),
            decoration: pw.BoxDecoration(
              color: isChecked ? PdfColors.blue600 : PdfColors.white,
              borderRadius: pw.BorderRadius.circular(2.5),
              border: pw.Border.all(
                color: isChecked ? PdfColors.blue600 : PdfColors.grey600,
                width: 1,
              ),
            ),
            child: isChecked
                ? pw.Center(
                    child: pw.Container(
                      width: 5,
                      height: 5,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          pw.Expanded(
            child: pw.RichText(
              text: _parseInlineMarkdown(
                text,
                baseFontSize: 10,
                isStrikethrough: isChecked,
                overrideColor: isChecked ? PdfColors.grey500 : PdfColors.grey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBulletListWidget(String text, int indentLevel) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indentLevel * 14.0, top: 2, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 4,
            height: 4,
            margin: const pw.EdgeInsets.only(top: 4.5, right: 6),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue700,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.RichText(
              text: _parseInlineMarkdown(text, baseFontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNumberedListWidget(String numStr, String text, int indentLevel) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indentLevel * 14.0, top: 2, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$numStr. ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
          pw.Expanded(
            child: pw.RichText(
              text: _parseInlineMarkdown(text, baseFontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBlockquoteWidget(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        border: pw.Border(left: pw.BorderSide(color: PdfColors.blue600, width: 3.5)),
      ),
      child: pw.RichText(
        text: _parseInlineMarkdown(
          text,
          baseFontSize: 10,
          isItalic: true,
          overrideColor: PdfColors.blueGrey800,
        ),
      ),
    );
  }

  static pw.Widget _buildToggleWidget(String title, String body) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '> $title',
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          if (body.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10),
              child: pw.RichText(text: _parseInlineMarkdown(body, baseFontSize: 9.5)),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildParagraphWidget(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.RichText(
        text: _parseInlineMarkdown(text, baseFontSize: 10),
      ),
    );
  }

  static pw.TextSpan _parseInlineMarkdown(
    String text, {
    double baseFontSize = 10,
    bool isItalic = false,
    bool isStrikethrough = false,
    PdfColor? overrideColor,
  }) {
    final defaultColor = overrideColor ?? PdfColors.grey900;
    final spans = <pw.InlineSpan>[];

    // Clean custom [color=...] and [bg=...] tags if present
    String processed = text
        .replaceAll(RegExp(r'\[color=#[0-9A-Fa-f]{6}\]'), '')
        .replaceAll('[/color]', '')
        .replaceAll(RegExp(r'\[bg=#[0-9A-Fa-f]{6}\]'), '')
        .replaceAll('[/bg]', '');

    // Regex to detect markdown inline patterns: **bold**, *italic*, ~~strike~~, `code`, [link](url)
    final tokenRegex = RegExp(
      r'(\*\*[^*]+\*\*|\*[^*]+\*|~~[^~]+~~|`[^`]+`|\[[^\]]+\]\([^\)]+\))',
    );

    int lastIndex = 0;
    for (final match in tokenRegex.allMatches(processed)) {
      if (match.start > lastIndex) {
        spans.add(
          pw.TextSpan(
            text: processed.substring(lastIndex, match.start),
            style: pw.TextStyle(
              fontSize: baseFontSize,
              color: defaultColor,
              fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
              decoration: isStrikethrough ? pw.TextDecoration.lineThrough : null,
              lineSpacing: 1.8,
            ),
          ),
        );
      }

      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
        spans.add(
          pw.TextSpan(
            text: token.substring(2, token.length - 2),
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontWeight: pw.FontWeight.bold,
              color: defaultColor,
              decoration: isStrikethrough ? pw.TextDecoration.lineThrough : null,
            ),
          ),
        );
      } else if (token.startsWith('*') && token.endsWith('*') && token.length >= 2) {
        spans.add(
          pw.TextSpan(
            text: token.substring(1, token.length - 1),
            style: pw.TextStyle(
              fontSize: baseFontSize,
              fontStyle: pw.FontStyle.italic,
              color: defaultColor,
              decoration: isStrikethrough ? pw.TextDecoration.lineThrough : null,
            ),
          ),
        );
      } else if (token.startsWith('~~') && token.endsWith('~~') && token.length >= 4) {
        spans.add(
          pw.TextSpan(
            text: token.substring(2, token.length - 2),
            style: pw.TextStyle(
              fontSize: baseFontSize,
              decoration: pw.TextDecoration.lineThrough,
              color: PdfColors.grey600,
            ),
          ),
        );
      } else if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
        spans.add(
          pw.TextSpan(
            text: token.substring(1, token.length - 1),
            style: pw.TextStyle(
              font: pw.Font.courier(),
              fontSize: baseFontSize * 0.9,
              color: PdfColors.purple800,
              background: pw.BoxDecoration(color: PdfColors.grey100),
            ),
          ),
        );
      } else if (token.startsWith('[') && token.contains('](') && token.endsWith(')')) {
        final linkTextMatch = RegExp(r'^\[([^\]]+)\]\(([^\)]+)\)$').firstMatch(token);
        if (linkTextMatch != null) {
          final label = linkTextMatch.group(1)!;
          spans.add(
            pw.TextSpan(
              text: label,
              style: pw.TextStyle(
                fontSize: baseFontSize,
                color: PdfColors.blue700,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          );
        }
      }

      lastIndex = match.end;
    }

    if (lastIndex < processed.length) {
      spans.add(
        pw.TextSpan(
          text: processed.substring(lastIndex),
          style: pw.TextStyle(
            fontSize: baseFontSize,
            color: defaultColor,
            fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
            decoration: isStrikethrough ? pw.TextDecoration.lineThrough : null,
            lineSpacing: 1.8,
          ),
        ),
      );
    }

    return pw.TextSpan(children: spans);
  }
}
