import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'resume_pdf_web.dart'
    if (dart.library.io) 'resume_pdf_stub.dart'
    as web_dl;

class ResumePdfService {
  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _italic;

  /// Downloads Roboto fonts from reliable Google Fonts CDN with fallback URLs.
  static Future<void> _loadFonts() async {
    if (_regular != null && _bold != null) return;

    // Primary: google/fonts repo (stable, well-known path)
    // Fallback: googlefonts/roboto repo alternate path
    final regularUrls = [
      'https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Regular.ttf',
      'https://github.com/googlefonts/roboto-2/raw/main/src/hinted-base/Roboto-Regular.ttf',
    ];
    final boldUrls = [
      'https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Bold.ttf',
      'https://github.com/googlefonts/roboto-2/raw/main/src/hinted-base/Roboto-Bold.ttf',
    ];
    final italicUrls = [
      'https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Italic.ttf',
    ];

    Future<Uint8List?> tryDownload(List<String> urls) async {
      for (final url in urls) {
        try {
          final res = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));
          if (res.statusCode == 200 && res.bodyBytes.length > 10000) {
            return res.bodyBytes;
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    }

    final regBytes = await tryDownload(regularUrls);
    final boldBytes = await tryDownload(boldUrls);
    final itaBytes = await tryDownload(italicUrls);

    if (regBytes != null) _regular = pw.Font.ttf(regBytes.buffer.asByteData());
    if (boldBytes != null) _bold = pw.Font.ttf(boldBytes.buffer.asByteData());
    if (itaBytes != null) _italic = pw.Font.ttf(itaBytes.buffer.asByteData());
  }

  Future<String> generatePdf({
    required String resumeText,
    required String fileName,
  }) async {
    await _loadFonts();

    // Normalise smart punctuation regardless of font availability
    final safe = resumeText
        .replaceAll('\u2013', '-') // en-dash
        .replaceAll('\u2014', '--') // em-dash
        .replaceAll('\u20b9', 'Rs.') // ₹
        .replaceAll('\u2019', "'") // curly apostrophe
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"'); // curly quotes
    // NOTE: we intentionally do NOT strip \u2022 (bullet •) here anymore.
    // _buildPage handles it directly so the bullet glyph in the PDF
    // always comes from _bulletChar() which is font-safe.

    final theme = _regular != null
        ? pw.ThemeData.withFont(
            base: _regular!,
            bold: _bold ?? _regular!,
            italic: _italic ?? _regular!,
            boldItalic: _bold ?? _regular!,
          )
        : pw.ThemeData();

    final pdf = pw.Document(theme: theme);
    final lines = safe.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 50),
        build: (ctx) => _buildPage(lines),
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      web_dl.downloadPdfOnWeb(bytes, '$fileName.pdf');
      return '$fileName.pdf';
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName.pdf');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }

  /// Returns a bullet string that is safe for the current font.
  /// When Roboto loaded successfully → coloured •
  /// When only Helvetica is available → plain hyphen-minus (ASCII, always works)
  String _bulletChar() => _regular != null ? '\u2022  ' : '-  ';

  List<pw.Widget> _buildPage(List<String> lines) {
    final widgets = <pw.Widget>[];
    bool nameWritten = false;
    bool contactWritten = false;
    bool firstSection = true;

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 4));
        continue;
      }

      // ── Candidate name (first non-empty line) ─────────────────────────────
      if (!nameWritten) {
        nameWritten = true;
        widgets.add(
          pw.Text(
            line,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('1A1A2E'),
            ),
          ),
        );
        continue;
      }

      // ── Contact line (email / phone / LinkedIn / GitHub) ──────────────────
      if (!contactWritten &&
          (line.contains('@') ||
              line.contains('+91') ||
              line.toLowerCase().contains('github') ||
              line.toLowerCase().contains('linkedin') ||
              (line.contains('|') && line.length < 150))) {
        contactWritten = true;
        widgets.add(pw.SizedBox(height: 2));
        widgets.add(
          pw.Text(
            line,
            style: pw.TextStyle(
              fontSize: 9.5,
              color: PdfColor.fromHex('4B5563'),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(
          pw.Divider(color: PdfColor.fromHex('2D5BE3'), thickness: 1.5),
        );
        widgets.add(pw.SizedBox(height: 2));
        continue;
      }

      // ── Section headers ────────────────────────────────────────────────────
      if (_isSectionHeader(line)) {
        if (!firstSection) widgets.add(pw.SizedBox(height: 8));
        firstSection = false;
        widgets.add(
          pw.Text(
            line.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('2D5BE3'),
              letterSpacing: 1.2,
            ),
          ),
        );
        widgets.add(
          pw.Divider(color: PdfColor.fromHex('2D5BE3'), thickness: 0.6),
        );
        widgets.add(pw.SizedBox(height: 3));
        continue;
      }

      // ── Job / project row: "Company | Title | Dates" ──────────────────────
      if (line.contains('|') && !line.contains('@') && !_isBullet(line)) {
        final parts = line.split('|').map((s) => s.trim()).toList();
        widgets.add(pw.SizedBox(height: 5));
        widgets.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  parts.take(parts.length - 1).join(' | '),
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('111827'),
                  ),
                ),
              ),
              pw.Text(
                parts.last,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  color: PdfColor.fromHex('6B7280'),
                ),
              ),
            ],
          ),
        );
        continue;
      }

      // ── Bullet points ──────────────────────────────────────────────────────
      if (_isBullet(line)) {
        final stripped = line.trimLeft();
        // Strip leading bullet marker (•, -, *) and any following spaces
        final content = stripped.replaceFirst(RegExp(r'^[•\-\*]\s*'), '');
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 1),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _bulletChar(), // ← font-safe: • with Roboto, - with Helvetica
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('2D5BE3'),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    content,
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // ── Skills line "Label: values" ───────────────────────────────────────
      final colonIdx = line.indexOf(':');
      if (colonIdx > 0 && colonIdx < 35 && !line.startsWith('http')) {
        final label = line.substring(0, colonIdx + 1);
        final value = line.substring(colonIdx + 1).trim();
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$label ',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('374151'),
                    ),
                  ),
                  pw.TextSpan(
                    text: value,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        );
        continue;
      }

      // ── Default plain text ─────────────────────────────────────────────────
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            line,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.3),
          ),
        ),
      );
    }
    return widgets;
  }

  /// True if line starts with a bullet marker (•, -, *)
  bool _isBullet(String line) {
    final s = line.trimLeft();
    return s.startsWith('\u2022') || s.startsWith('- ') || s.startsWith('* ');
  }

  bool _isSectionHeader(String line) {
    final t = line.trim();
    if (t.length < 3 || t.length > 40) return false;
    if (t == t.toUpperCase() && !t.contains('@') && !t.contains('+'))
      return true;
    const known = [
      'Experience',
      'Work Experience',
      'Professional Experience',
      'Education',
      'Skills',
      'Technical Skills',
      'Projects',
      'Summary',
      'Professional Summary',
      'Objective',
      'Certifications',
      'Achievements',
      'Awards',
      'Publications',
      'TECHNICAL SKILLS',
      'WORK EXPERIENCE',
      'PROFESSIONAL SUMMARY',
      'EDUCATION',
      'PROJECTS',
      'EXPERIENCE',
      'CERTIFICATIONS',
    ];
    return known.any((h) => t.toLowerCase() == h.toLowerCase());
  }

  Future<void> openPdf(String path) async {
    if (!kIsWeb) await OpenFile.open(path);
  }

  Future<void> sharePdf(String path, {String subject = 'My Resume'}) async {
    if (!kIsWeb) {
      await Share.shareXFiles([
        XFile(path, mimeType: 'application/pdf'),
      ], subject: subject);
    }
  }
}
