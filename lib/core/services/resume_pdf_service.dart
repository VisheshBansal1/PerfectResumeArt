import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
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
import 'interview_prep_service.dart'

    show JobFitReport, InterviewQA, InterviewQuestionCategory, InterviewQuestionCategoryX;

// ─────────────────────────────────────────────────────────────────────────
// RESUME TEMPLATES
//
// Every template reuses the exact same proven text-parsing layout logic
// (_buildPage below) — only color, header treatment, and bullet style
// change. This keeps rendering behavior well-tested while still giving a
// genuinely different visual identity per template.
// ─────────────────────────────────────────────────────────────────────────

enum ResumeBulletStyle { dot, dash, square }

class ResumeTemplateStyle {
  final String id;
  final String name;
  final String description;
  final String nameHex;
  final String accentHex;
  final String secondaryHex;
  final String bodyHex;
  final double headerLetterSpacing;
  final double dividerThicknessThin;
  final double dividerThicknessBold;
  final double nameFontSize;
  final ResumeBulletStyle bulletStyle;

  const ResumeTemplateStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.nameHex,
    required this.accentHex,
    required this.secondaryHex,
    required this.bodyHex,
    this.headerLetterSpacing = 1.2,
    this.dividerThicknessThin = 0.6,
    this.dividerThicknessBold = 1.5,
    this.nameFontSize = 22,
    this.bulletStyle = ResumeBulletStyle.dot,
  });

  PdfColor get namePdf => PdfColor.fromHex(nameHex);
  PdfColor get accentPdf => PdfColor.fromHex(accentHex);
  PdfColor get secondaryPdf => PdfColor.fromHex(secondaryHex);
  PdfColor get bodyPdf => PdfColor.fromHex(bodyHex);

  /// For UI swatches/previews in the template picker (Flutter Color, not PdfColor).
  Color get accentFlutterColor => Color(int.parse('FF$accentHex', radix: 16));
  Color get nameFlutterColor => Color(int.parse('FF$nameHex', radix: 16));
}

class ResumeTemplates {
  ResumeTemplates._();

  static const classicBlue = ResumeTemplateStyle(
    id: 'classic_blue',
    name: 'Classic Blue',
    description: 'Clean and professional — safe for any role or industry',
    nameHex: '1A1A2E',
    accentHex: '2D5BE3',
    secondaryHex: '6B7280',
    bodyHex: '111827',
    headerLetterSpacing: 1.2,
    dividerThicknessThin: 0.6,
    dividerThicknessBold: 1.5,
    nameFontSize: 22,
    bulletStyle: ResumeBulletStyle.dot,
  );

  static const modernTeal = ResumeTemplateStyle(
    id: 'modern_teal',
    name: 'Modern Teal',
    description: 'Confident and current — great for tech and product roles',
    nameHex: '0F172A',
    accentHex: '0D9488',
    secondaryHex: '64748B',
    bodyHex: '111827',
    headerLetterSpacing: 1.5,
    dividerThicknessThin: 0.8,
    dividerThicknessBold: 1.8,
    nameFontSize: 23,
    bulletStyle: ResumeBulletStyle.square,
  );

  static const minimalistMono = ResumeTemplateStyle(
    id: 'minimalist_mono',
    name: 'Minimalist',
    description: 'Understated black & white — lets the content speak',
    nameHex: '000000',
    accentHex: '374151',
    secondaryHex: '6B7280',
    bodyHex: '1F2937',
    headerLetterSpacing: 2.0,
    dividerThicknessThin: 0.4,
    dividerThicknessBold: 0.8,
    nameFontSize: 20,
    bulletStyle: ResumeBulletStyle.dash,
  );

  static const boldViolet = ResumeTemplateStyle(
    id: 'bold_violet',
    name: 'Bold Violet',
    description: 'Distinctive accent — for startup, design, and creative-tech roles',
    nameHex: '1E1B2E',
    accentHex: '7C3AED',
    secondaryHex: '6B7280',
    bodyHex: '111827',
    headerLetterSpacing: 1.3,
    dividerThicknessThin: 0.8,
    dividerThicknessBold: 2.0,
    nameFontSize: 24,
    bulletStyle: ResumeBulletStyle.square,
  );

  static const elegantMaroon = ResumeTemplateStyle(
    id: 'elegant_maroon',
    name: 'Elegant Maroon',
    description: 'Refined and traditional — for business, finance, and legal roles',
    nameHex: '1F1315',
    accentHex: '9F1239',
    secondaryHex: '78716C',
    bodyHex: '1C1917',
    headerLetterSpacing: 1.0,
    dividerThicknessThin: 0.6,
    dividerThicknessBold: 1.5,
    nameFontSize: 22,
    bulletStyle: ResumeBulletStyle.dot,
  );

  static const all = [classicBlue, modernTeal, minimalistMono, boldViolet, elegantMaroon];

  static ResumeTemplateStyle byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => classicBlue);

  /// Picks a sensible default template from resume content when the user
  /// hasn't chosen one explicitly — a starting point, not a locked-in
  /// choice, since the picker always lets them switch.
  static ResumeTemplateStyle autoDetect(String resumeText) {
    final lower = resumeText.toLowerCase();

    int score(List<String> keywords) =>
        keywords.where((k) => lower.contains(k)).length;

    final techScore = score(const [
      'flutter', 'android', 'ios', 'react', 'developer', 'engineer', 'software',
      'backend', 'frontend', 'full stack', 'devops', 'cloud computing', 'python',
      'java ', 'kotlin', 'swift', 'rest api', 'database', 'sql', 'machine learning',
      'data scientist', 'programming', 'github', 'kubernetes', 'docker', 'aws',
    ]);
    final businessScore = score(const [
      'finance', 'accounting', 'banking', 'sales', 'marketing', 'business analyst',
      'consultant', 'operations manager', 'mba', 'hr ', 'human resources', 'legal',
      'audit', 'stakeholder management', 'p&l', 'financial analysis', 'compliance',
    ]);
    final designScore = score(const [
      'ux design', 'ui design', 'graphic design', 'product design', 'figma',
      'adobe', 'creative director', 'visual design', 'user research', 'prototyping',
    ]);

    if (designScore > 0 && designScore >= techScore && designScore >= businessScore) {
      return boldViolet;
    }
    if (businessScore > techScore) return elegantMaroon;
    if (techScore > 0) return modernTeal;
    return classicBlue;
  }
}

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
    ResumeTemplateStyle? template,
  }) async {
    await _loadFonts();
    final style = template ?? ResumeTemplates.autoDetect(resumeText);

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
        build: (ctx) => _buildPage(lines, style),
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

  /// Returns a bullet string that is safe for the current font and matches
  /// the template's bullet style.
  /// When Roboto loaded successfully → the template's glyph
  /// When only Helvetica is available → plain hyphen-minus (ASCII, always works)
  String _bulletChar(ResumeTemplateStyle style) {
    if (_regular == null) return '-  ';
    switch (style.bulletStyle) {
      case ResumeBulletStyle.dot:
        return '\u2022  ';
      case ResumeBulletStyle.dash:
        return '\u2013  ';
      case ResumeBulletStyle.square:
        return '\u25aa  ';
    }
  }

  List<pw.Widget> _buildPage(List<String> lines, ResumeTemplateStyle style) {
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
              fontSize: style.nameFontSize,
              fontWeight: pw.FontWeight.bold,
              color: style.namePdf,
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
              color: style.secondaryPdf,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(
          pw.Divider(color: style.accentPdf, thickness: style.dividerThicknessBold),
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
              color: style.accentPdf,
              letterSpacing: style.headerLetterSpacing,
            ),
          ),
        );
        widgets.add(
          pw.Divider(color: style.accentPdf, thickness: style.dividerThicknessThin),
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
                    color: style.bodyPdf,
                  ),
                ),
              ),
              pw.Text(
                parts.last,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  color: style.secondaryPdf,
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
                  _bulletChar(style),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: style.accentPdf,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    content,
                    style: pw.TextStyle(fontSize: 10, lineSpacing: 1.4, color: style.bodyPdf),
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
                      color: style.secondaryPdf,
                    ),
                  ),
                  pw.TextSpan(
                    text: value,
                    style: pw.TextStyle(fontSize: 10, color: style.bodyPdf),
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
            style: pw.TextStyle(fontSize: 10, lineSpacing: 1.3, color: style.bodyPdf),
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

  // ─── Interview Prep Report PDF ───────────────────────────────────────────
  // Renders the full JobFitReport (analysis + all unlocked interview
  // questions, grouped by round) as a standalone multi-page PDF — the
  // "downloadable format" from the ₹39 unlock.

  static const _ppPrimary = '#2D5BE3';
  static const _ppAccent = '#00C49A';
  static const _ppSuccess = '#43A047';
  static const _ppWarning = '#FFA726';
  static const _ppDanger = '#E53935';
  static const _ppTextDark = '#0D1117';
  static const _ppTextGrey = '#6B7280';
  static const _ppBorder = '#E5E7EB';
  static const _ppSurface = '#F8F9FE';

  /// Normalises characters the loaded font may not have a glyph for —
  /// mirrors the safety pass in generatePdf() above.
  String _ppSafe(String text) => text
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '--')
      .replaceAll('\u20b9', 'Rs.')
      .replaceAll('\u2019', "'")
      .replaceAll('\u2018', "'")
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"')
      .replaceAll('\u2022', '-');

  Future<String> generateInterviewPrepPdf({
    required JobFitReport report,
    required String candidateName,
    required String fileName,
  }) async {
    await _loadFonts();

    final theme = _regular != null
        ? pw.ThemeData.withFont(
            base: _regular!,
            bold: _bold ?? _regular!,
            italic: _italic ?? _regular!,
            boldItalic: _bold ?? _regular!,
          )
        : pw.ThemeData();

    final primary = PdfColor.fromHex(_ppPrimary);
    final accent = PdfColor.fromHex(_ppAccent);
    final success = PdfColor.fromHex(_ppSuccess);
    final warning = PdfColor.fromHex(_ppWarning);
    final danger = PdfColor.fromHex(_ppDanger);
    final textDark = PdfColor.fromHex(_ppTextDark);
    final textGrey = PdfColor.fromHex(_ppTextGrey);
    final border = PdfColor.fromHex(_ppBorder);
    final surface = PdfColor.fromHex(_ppSurface);

    PdfColor scoreColor(int score) {
      if (score >= 80) return success;
      if (score >= 65) return primary;
      if (score >= 50) return warning;
      return danger;
    }

    pw.Widget sectionHeading(String number, String title) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 18, bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: border, width: 1)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            '$number  ',
            style: pw.TextStyle(
              color: primary,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            _ppSafe(title),
            style: pw.TextStyle(
              color: textDark,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    pw.Widget bodyText(String text, {PdfColor? color, double size = 10.5}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            _ppSafe(text),
            style: pw.TextStyle(
              color: color ?? textDark,
              fontSize: size,
              lineSpacing: 1.4,
            ),
          ),
        );

    pw.Widget bulletList(List<String> items, {PdfColor? dotColor}) =>
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: items
              .map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
                        width: 4,
                        height: 4,
                        decoration: pw.BoxDecoration(
                          color: dotColor ?? primary,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          _ppSafe(item),
                          style: pw.TextStyle(
                            color: textDark,
                            fontSize: 10.5,
                            lineSpacing: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );

    pw.Widget chipWrap(List<String> items, PdfColor bg, PdfColor fg) =>
        pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (item) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: bg,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    _ppSafe(item),
                    style: pw.TextStyle(color: fg, fontSize: 9.5),
                  ),
                ),
              )
              .toList(),
        );

    pw.Widget statBox(String label, int value, PdfColor color) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10),
        margin: const pw.EdgeInsets.symmetric(horizontal: 3),
        decoration: pw.BoxDecoration(
          color: surface,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: border, width: 0.5),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              '$value',
              style: pw.TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _ppSafe(label),
              style: pw.TextStyle(color: textGrey, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );

    pw.Widget questionBlock(int index, InterviewQA qa) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: surface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  _ppSafe('Q$index. ${qa.question}'),
                  style: pw.TextStyle(
                    color: textDark,
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    lineSpacing: 1.3,
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: qa.difficulty == 'Hard'
                      ? danger
                      : (qa.difficulty == 'Easy' ? success : warning),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  qa.difficulty,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            _ppSafe(qa.answer),
            style: pw.TextStyle(color: textGrey, fontSize: 10, lineSpacing: 1.35),
          ),
        ],
      ),
    );

    final content = <pw.Widget>[];

    // ── Header ──
    content.add(
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 14),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: primary, width: 2)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'INTERVIEW PREPARATION REPORT',
              style: pw.TextStyle(
                color: primary,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _ppSafe('Prepared for $candidateName'),
              style: pw.TextStyle(color: textGrey, fontSize: 10),
            ),
          ],
        ),
      ),
    );

    // 1. Candidate Summary
    content.add(sectionHeading('1', 'Candidate Summary'));
    if (report.recommendation.isNotEmpty) {
      content.add(bodyText(report.recommendation, color: primary, size: 11.5));
    }
    if (report.summary.isNotEmpty) content.add(bodyText(report.summary));

    // 2. ATS Report
    content.add(sectionHeading('2', 'ATS Report'));
    content.add(
      pw.Row(
        children: [
          statBox(
            'ATS Score',
            report.atsAnalysis.atsScore,
            scoreColor(report.atsAnalysis.atsScore),
          ),
          statBox(
            'Keyword Coverage',
            report.atsAnalysis.keywordCoverage,
            scoreColor(report.atsAnalysis.keywordCoverage),
          ),
          statBox(
            'Format',
            report.atsAnalysis.formatScore,
            scoreColor(report.atsAnalysis.formatScore),
          ),
          statBox(
            'Readability',
            report.atsAnalysis.readabilityScore,
            scoreColor(report.atsAnalysis.readabilityScore),
          ),
        ],
      ),
    );

    // 3. Resume Score
    content.add(sectionHeading('3', 'Resume Score'));
    content.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            '${report.overallScore}',
            style: pw.TextStyle(
              color: scoreColor(report.overallScore),
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4, left: 2, right: 10),
            child: pw.Text(
              '/100',
              style: pw.TextStyle(color: textGrey, fontSize: 12),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            margin: const pw.EdgeInsets.only(bottom: 4),
            decoration: pw.BoxDecoration(
              color: scoreColor(report.overallScore),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              _ppSafe(report.matchLabel),
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
    if (report.experienceMatch.isNotEmpty ||
        report.educationMatch.isNotEmpty ||
        report.projectAnalysis.isNotEmpty) {
      content.add(pw.SizedBox(height: 8));
      if (report.experienceMatch.isNotEmpty) {
        content.add(bodyText('Experience: ${report.experienceMatch}'));
      }
      if (report.educationMatch.isNotEmpty) {
        content.add(bodyText('Education: ${report.educationMatch}'));
      }
      if (report.projectAnalysis.isNotEmpty) {
        content.add(bodyText('Projects: ${report.projectAnalysis}'));
      }
    }

    // 4. Skill Match
    content.add(sectionHeading('4', 'Skill Match'));
    content.add(
      report.skillsMatched.isEmpty
          ? bodyText('No direct skill matches found.', color: textGrey)
          : chipWrap(report.skillsMatched, PdfColor.fromHex('#E8F5E9'), success),
    );

    // 5. Missing Skills
    content.add(sectionHeading('5', 'Missing Skills'));
    content.add(
      report.skillsMissing.isEmpty
          ? bodyText('No major skill gaps found.', color: textGrey)
          : chipWrap(report.skillsMissing, PdfColor.fromHex('#FDECEA'), danger),
    );
    if (report.topMissingKeywords.isNotEmpty) {
      content.add(pw.SizedBox(height: 6));
      content.add(
        bodyText('Top missing keywords:', color: textGrey, size: 9.5),
      );
      content.add(
        chipWrap(report.topMissingKeywords, PdfColor.fromHex('#FFF3E0'), warning),
      );
    }

    // 6. Resume Improvements
    content.add(sectionHeading('6', 'Resume Improvements'));
    content.add(
      report.resumeImprovements.isEmpty
          ? bodyText('No specific improvements flagged.', color: textGrey)
          : bulletList(report.resumeImprovements, dotColor: accent),
    );

    // 7. Selection Probability
    content.add(sectionHeading('7', 'Selection Probability'));
    if (report.selectionProbability.isNotEmpty) {
      content.add(bodyText(report.selectionProbability, color: primary, size: 11));
    }
    if (report.strengths.isNotEmpty) {
      content.add(pw.SizedBox(height: 6));
      content.add(
        pw.Text(
          'Strengths',
          style: pw.TextStyle(
            color: success,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
      content.add(pw.SizedBox(height: 3));
      content.add(bulletList(report.strengths, dotColor: success));
    }
    if (report.weaknesses.isNotEmpty) {
      content.add(pw.SizedBox(height: 6));
      content.add(
        pw.Text(
          'Areas to Address',
          style: pw.TextStyle(
            color: danger,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
      content.add(pw.SizedBox(height: 3));
      content.add(bulletList(report.weaknesses, dotColor: danger));
    }

    // 8+. Interview Questions, grouped by round
    final byCategory = report.questionsByCategory;
    const order = [
      InterviewQuestionCategory.hr,
      InterviewQuestionCategory.technical,
      InterviewQuestionCategory.coding,
      InterviewQuestionCategory.scenario,
      InterviewQuestionCategory.behavioural,
      InterviewQuestionCategory.project,
      InterviewQuestionCategory.resumeBased,
    ];
    int sectionNum = 8;
    int qNum = 1;
    for (final cat in order) {
      final qs = byCategory[cat];
      if (qs == null || qs.isEmpty) continue;
      content.add(sectionHeading('$sectionNum', '${cat.label} Interview Questions'));
      for (final qa in qs) {
        content.add(questionBlock(qNum, qa));
        qNum++;
      }
      sectionNum++;
    }

    // Final Recruiter Advice
    if (report.finalRecruiterAdvice.isNotEmpty) {
      content.add(sectionHeading('$sectionNum', 'Final Recruiter Advice'));
      content.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#EEF2FF'),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: primary, width: 0.5),
          ),
          child: bodyText(report.finalRecruiterAdvice, color: textDark, size: 10.5),
        ),
      );
    }

    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 50),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(color: textGrey, fontSize: 8),
          ),
        ),
        build: (ctx) => content,
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
