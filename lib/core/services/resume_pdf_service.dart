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

  /// Downloads Roboto fonts once and caches them — supports full Unicode
  static Future<void> _loadFonts() async {
    if (_regular != null && _bold != null) return;
    try {
      final regRes = await http.get(
        Uri.parse(
          'https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Regular.ttf',
        ),
      );
      final boldRes = await http.get(
        Uri.parse(
          'https://github.com/googlefonts/roboto/raw/main/src/hinted/Roboto-Bold.ttf',
        ),
      );
      if (regRes.statusCode == 200 && boldRes.statusCode == 200) {
        _regular = pw.Font.ttf(regRes.bodyBytes.buffer.asByteData());
        _bold = pw.Font.ttf(boldRes.bodyBytes.buffer.asByteData());
        return;
      }
    } catch (_) {
      // Font load failed — fall back to Helvetica with ASCII-safe text
      _regular = null;
      _bold = null;
    }
  }

  Future<String> generatePdf({
    required String resumeText,
    required String fileName,
  }) async {
    await _loadFonts();

    // Replace Unicode symbols that Helvetica can't render when Roboto fails to load.
    // When Roboto IS loaded these replacements still apply for consistency.
    final safe = resumeText
        .replaceAll(
          '\u2022',
          '-',
        ) // bullet •  -> -  (PDF renderer uses its own bullet styling)
        .replaceAll('\u2013', '-') // en-dash
        .replaceAll('\u2014', '--') // em-dash
        .replaceAll('\u20b9', 'Rs.') // ₹ -> Rs.
        .replaceAll('\u2019', "'") // curly apostrophe
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"'); // curly quotes

    final theme = _regular != null
        ? pw.ThemeData.withFont(base: _regular!, bold: _bold ?? _regular!)
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

      // ── First non-empty line = candidate name ──────────────────────────────
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

      // ── Contact line (email, phone, LinkedIn, GitHub) ──────────────────────
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

      // ── Section headers (ALLCAPS or known keywords) ────────────────────────
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

      // ── Job / project line: "Company | Title | Dates" ─────────────────────
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

      // ── Bullet points — handles •, -, * (AI resume uses all three) ─────────
      if (_isBullet(line)) {
        // Strip leading whitespace then strip the bullet character + spaces
        final stripped = line.trimLeft();
        // Remove •, -, or * at the start followed by optional spaces
        final content = stripped.replaceFirst(RegExp(r'^[•\-\*]\s*'), '');
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12, top: 2, bottom: 1),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '•  ',
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

      // ── Skills line "Label: values..." ────────────────────────────────────
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

  /// Returns true if the line starts with a bullet character (•, -, *).
  bool _isBullet(String line) {
    final s = line.trimLeft();
    return s.startsWith('•') || s.startsWith('- ') || s.startsWith('* ');
  }

  bool _isSectionHeader(String line) {
    final t = line.trim();
    if (t.length < 3 || t.length > 40) return false;
    // All-caps line that isn't a contact detail
    if (t == t.toUpperCase() && !t.contains('@') && !t.contains('+'))
      return true;
    // Known mixed-case section titles
    const known = [
      'Experience', 'Work Experience', 'Professional Experience',
      'Education', 'Skills', 'Technical Skills', 'Projects',
      'Summary', 'Professional Summary', 'Objective',
      'Certifications', 'Achievements', 'Awards', 'Publications',
      // ALL-CAPS variants (matched by the rule above, but kept for safety)
      'TECHNICAL SKILLS', 'WORK EXPERIENCE', 'PROFESSIONAL SUMMARY',
      'EDUCATION', 'PROJECTS', 'EXPERIENCE', 'CERTIFICATIONS',
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
