import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdf/pdf.dart';

// ML Kit is mobile-only — conditional import avoids web crash
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    if (dart.library.html) 'ocr_web_stub.dart';

class OcrService {
  // Lazy — only created on first use on mobile, never on web
  TextRecognizer? _textRecognizer;

  TextRecognizer get _recognizer {
    if (kIsWeb) throw OcrException('ML Kit is not supported on web.');
    return _textRecognizer ??=
        TextRecognizer(script: TextRecognitionScript.latin);
  }

  // ── Mobile: File path based ─────────────────────────────────────

  Future<OcrResult> extractTextFromImage(File imageFile) async {
    if (kIsWeb) {
      throw OcrException(
        'Image OCR is not supported on web. Please upload a PDF instead.',
      );
    }
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _recognizer.processImage(inputImage);
      final text = recognized.text;
      final confidence = _calculateConfidence(recognized);
      if (confidence < 0.6 || text.trim().length < 100) {
        return OcrResult(
          text: text, confidence: confidence,
          source: 'mlkit', needsFallback: true,
        );
      }
      return OcrResult(
        text: _cleanText(text), confidence: confidence,
        source: 'mlkit', needsFallback: false,
      );
    } catch (e) {
      throw OcrException('Failed to extract text from image: $e');
    }
  }

  Future<OcrResult> extractTextFromPdf(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      return _extractFromPdfBytes(bytes);
    } catch (e) {
      throw OcrException('Failed to extract text from PDF: $e');
    }
  }

  /// Mobile/Desktop only — File has a real path.
  Future<OcrResult> extractText(File file) async {
    final extension = file.path.split('.').last.toLowerCase().trim();
    if (extension == 'pdf') return extractTextFromPdf(file);
    if (['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension)) {
      return extractTextFromImage(file);
    }
    throw OcrException(
      'Unsupported file type ".$extension". Please upload a PDF, JPG, or PNG.',
    );
  }

  // ── Web + Mobile: Bytes based ───────────────────────────────────

  Future<OcrResult> extractTextFromBytes({
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.toLowerCase().trim().replaceAll('.', '');

    if (ext == 'pdf') return _extractFromPdfBytes(bytes);

    if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (kIsWeb) {
        throw OcrException(
          'Image OCR is not supported on web. Please upload a PDF instead.',
        );
      }
      // Mobile: write bytes to temp file, run ML Kit
      final tempPath =
          '${Directory.systemTemp.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes);
      try {
        return await extractTextFromImage(tempFile);
      } finally {
        await tempFile.delete().catchError((_) => tempFile);
      }
    }

    throw OcrException(
      'Unsupported file type ".$ext". Please upload a PDF, JPG, or PNG.',
    );
  }

  // ── Internal ────────────────────────────────────────────────────

  Future<OcrResult> _extractFromPdfBytes(Uint8List bytes) async {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();
      for (int i = 0; i < document.pages.count; i++) {
        buffer.writeln(
          extractor.extractText(startPageIndex: i, endPageIndex: i),
        );
      }
      document.dispose();
      final text = buffer.toString();
      return OcrResult(
        text: _cleanText(text),
        confidence: 0.95,
        source: 'pdf_extractor',
        needsFallback: text.trim().length < 50,
      );
    } catch (e) {
      throw OcrException('Failed to extract text from PDF: $e');
    }
  }

  double _calculateConfidence(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          total += element.confidence ?? 0;
          count++;
        }
      }
    }
    return count > 0 ? total / count : 0;
  }

  String _cleanText(String raw) => raw
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'[^\x20-\x7E\n]'), '')
      .trim();

  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}

class OcrResult {
  final String text;
  final double confidence;
  final String source;
  final bool needsFallback;
  const OcrResult({
    required this.text,
    required this.confidence,
    required this.source,
    required this.needsFallback,
  });
}

class OcrException implements Exception {
  final String message;
  const OcrException(this.message);
  @override
  String toString() => 'OcrException: $message';
}
