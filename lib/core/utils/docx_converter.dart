import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Result of parsing a .docx file.
class DocxResult {
  final String title;
  final String content; // Markdown formatted
  final String summary;

  const DocxResult({
    required this.title,
    required this.content,
    required this.summary,
  });
}

/// Converts a .docx file (as raw bytes) into a [DocxResult] with Markdown content.
///
/// A .docx file is a ZIP archive containing XML files. We parse:
///   - `word/document.xml` → paragraphs, headings, bullets, bold, italic
///
/// Heading detection priority:
///   1. Word paragraph styles (Heading1, Heading2, Heading3)
///   2. Short bold-only paragraphs (fallback for manually formatted docs)
class DocxConverter {
  static DocxResult convert(Uint8List bytes) {
    // --- Unzip the .docx ---
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      return const DocxResult(
        title: '',
        content: '',
        summary: '',
      );
    }

    final xmlString = String.fromCharCodes(docFile.content as List<int>);
    final doc = XmlDocument.parse(xmlString);

    // --- Parse paragraphs ---
    final paragraphs = doc.findAllElements('w:p');
    final buffer = StringBuffer();
    String detectedTitle = '';
    bool titleFound = false;

    for (final para in paragraphs) {
      final style = _getParagraphStyle(para);
      final text = _extractText(para);
      final isBold = _isEntirelyBold(para);
      final isBullet = _isBulletParagraph(para);
      final isNumbered = _isNumberedParagraph(para);

      if (text.trim().isEmpty) {
        buffer.writeln();
        continue;
      }

      // --- Heading detection ---
      if (style == 'Heading1' || style == 'Title') {
        if (!titleFound) {
          detectedTitle = text.trim();
          titleFound = true;
        }
        buffer.writeln('# ${text.trim()}');
        buffer.writeln();
      } else if (style == 'Heading2') {
        buffer.writeln('## ${text.trim()}');
        buffer.writeln();
      } else if (style == 'Heading3' || style == 'Heading4') {
        buffer.writeln('### ${text.trim()}');
        buffer.writeln();
      }
      // Fallback: short bold-only line → treat as heading
      else if (isBold &&
          text.trim().length <= 80 &&
          !text.trim().endsWith('.') &&
          !text.trim().endsWith(',')) {
        if (!titleFound) {
          detectedTitle = text.trim();
          titleFound = true;
          buffer.writeln('# ${text.trim()}');
        } else {
          buffer.writeln('## ${text.trim()}');
        }
        buffer.writeln();
      }
      // Bullet list item
      else if (isBullet) {
        buffer.writeln('- ${_extractRichText(para)}');
      }
      // Numbered list item
      else if (isNumbered) {
        buffer.writeln('1. ${_extractRichText(para)}');
      }
      // Normal paragraph
      else {
        buffer.writeln(_extractRichText(para));
        buffer.writeln();
      }
    }

    final content = buffer.toString().trim();

    // Summary = first 200 chars of plain text
    final plainText = content
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'^-\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
        .trim();

    final summary = plainText.length > 200
        ? '${plainText.substring(0, 200)}...'
        : plainText;

    return DocxResult(
      title: detectedTitle,
      content: content,
      summary: summary,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns the Word paragraph style name (e.g. "Heading1", "Normal").
  static String _getParagraphStyle(XmlElement para) {
    final pPr = para.findElements('w:pPr').firstOrNull;
    if (pPr == null) return 'Normal';
    final pStyle = pPr.findElements('w:pStyle').firstOrNull;
    final val = pStyle?.getAttribute('w:val') ?? 'Normal';
    // Normalise e.g. "Heading 1" → "Heading1"
    return val.replaceAll(' ', '');
  }

  /// Returns true if the paragraph is a bullet list item.
  static bool _isBulletParagraph(XmlElement para) {
    final pPr = para.findElements('w:pPr').firstOrNull;
    if (pPr == null) return false;
    final numPr = pPr.findElements('w:numPr').firstOrNull;
    if (numPr == null) return false;
    final ilvl = numPr.findElements('w:ilvl').firstOrNull;
    final numId = numPr.findElements('w:numId').firstOrNull;
    final numIdVal = numId?.getAttribute('w:val') ?? '0';
    // numId=0 means no list; ilvl attribute present = list
    return numIdVal != '0' && ilvl != null;
  }

  /// Returns true if the paragraph is a numbered list item.
  static bool _isNumberedParagraph(XmlElement para) {
    final style = _getParagraphStyle(para);
    return style.toLowerCase().contains('listparagraph') ||
        style.toLowerCase().contains('listbullet') ||
        style.toLowerCase().contains('listnumber');
  }

  /// Returns true if ALL runs in the paragraph are bold.
  static bool _isEntirelyBold(XmlElement para) {
    final runs = para.findElements('w:r').toList();
    if (runs.isEmpty) return false;
    for (final run in runs) {
      final rPr = run.findElements('w:rPr').firstOrNull;
      if (rPr == null) return false;
      final bold = rPr.findElements('w:b').firstOrNull;
      if (bold == null) return false;
    }
    return true;
  }

  /// Extracts plain text from a paragraph (no formatting).
  static String _extractText(XmlElement para) {
    final sb = StringBuffer();
    for (final t in para.findAllElements('w:t')) {
      sb.write(t.innerText);
    }
    return sb.toString();
  }

  /// Extracts text with inline Markdown bold/italic formatting.
  static String _extractRichText(XmlElement para) {
    final sb = StringBuffer();
    for (final run in para.findElements('w:r')) {
      final rPr = run.findElements('w:rPr').firstOrNull;
      final isBold =
          rPr?.findElements('w:b').isNotEmpty ?? false;
      final isItalic =
          rPr?.findElements('w:i').isNotEmpty ?? false;

      final text =
          run.findAllElements('w:t').map((e) => e.innerText).join();

      if (text.isEmpty) continue;

      if (isBold && isItalic) {
        sb.write('***$text***');
      } else if (isBold) {
        sb.write('**$text**');
      } else if (isItalic) {
        sb.write('*$text*');
      } else {
        sb.write(text);
      }
    }
    return sb.toString();
  }
}
