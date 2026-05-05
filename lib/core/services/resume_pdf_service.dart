import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class ResumePdfService {
  /// Generates a clean ATS-friendly PDF from plain resume text.
  /// Returns the file path on success.
  Future<String> generatePdf({
    required String resumeText,
    required String fileName,
  }) async {
    final pdf = pw.Document();
    final lines = resumeText.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 52),
        build: (context) {
          final widgets = <pw.Widget>[];

          for (final rawLine in lines) {
            final line = rawLine.trimRight();
            if (line.isEmpty) {
              widgets.add(pw.SizedBox(height: 6));
              continue;
            }

            // Detect name (first non-empty line)
            if (widgets.isEmpty || (widgets.length == 1 && widgets.first is pw.SizedBox)) {
              widgets.add(
                pw.Text(
                  line,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('2D5BE3'),
                  ),
                ),
              );
              continue;
            }

            // Detect section headers (all caps or ends with :)
            final isHeader = _isSectionHeader(line);
            if (isHeader) {
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(
                pw.Column(children: [
                  pw.Text(
                    line.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('2D5BE3'),
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.Divider(color: PdfColor.fromHex('2D5BE3'), thickness: 0.8),
                ]),
              );
              continue;
            }

            // Bullet points
            if (line.trimLeft().startsWith('•') ||
                line.trimLeft().startsWith('-') ||
                line.trimLeft().startsWith('*')) {
              final content = line.trimLeft().replaceFirst(RegExp(r'^[•\-\*]\s*'), '');
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, top: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• ', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('2D5BE3'))),
                      pw.Expanded(
                        child: pw.Text(
                          content,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              continue;
            }

            // Contact line (contains @ or github or linkedin)
            if (line.contains('@') || line.toLowerCase().contains('github') || line.toLowerCase().contains('linkedin')) {
              widgets.add(
                pw.Text(
                  line,
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('4B5563')),
                ),
              );
              continue;
            }

            // Default text
            widgets.add(
              pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 10.5),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  bool _isSectionHeader(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    // All caps check
    if (trimmed == trimmed.toUpperCase() && trimmed.length > 2 && !trimmed.contains('@')) {
      return true;
    }
    // Common resume headers
    final headers = [
      'Experience', 'Work Experience', 'Education', 'Skills', 'Projects',
      'Summary', 'Objective', 'Certifications', 'Achievements', 'Awards',
      'Technical Skills', 'Professional Experience', 'Career Objective',
    ];
    return headers.any((h) => trimmed.toLowerCase().startsWith(h.toLowerCase()));
  }

  Future<void> openPdf(String path) async {
    await OpenFile.open(path);
  }

  Future<void> sharePdf(String path, {String subject = 'My Improved Resume'}) async {
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf')],
      subject: subject,
    );
  }
}
