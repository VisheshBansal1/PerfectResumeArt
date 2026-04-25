import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract text from image using ML Kit
  Future<OcrResult> extractTextFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await _textRecognizer.processImage(inputImage);

      final text = recognized.text;
      final confidence = _calculateConfidence(recognized);

      if (confidence < 0.6 || text.trim().length < 100) {
        // Low accuracy — you could fall back to Cloud Vision here
        return OcrResult(
          text: text,
          confidence: confidence,
          source: 'mlkit',
          needsFallback: true,
        );
      }

      return OcrResult(
        text: _cleanText(text),
        confidence: confidence,
        source: 'mlkit',
        needsFallback: false,
      );
    } catch (e) {
      throw OcrException('Failed to extract text from image: $e');
    }
  }

  /// Extract text from PDF
  Future<OcrResult> extractTextFromPdf(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);

      final buffer = StringBuffer();
      for (int i = 0; i < document.pages.count; i++) {
        final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
        buffer.writeln(pageText);
      }
      document.dispose();

      final text = buffer.toString();
      return OcrResult(
        text: _cleanText(text),
        confidence: 0.95, // PDFs have near-perfect text fidelity
        source: 'pdf_extractor',
        needsFallback: text.trim().length < 50,
      );
    } catch (e) {
      throw OcrException('Failed to extract text from PDF: $e');
    }
  }

  /// Auto-detect file type and extract accordingly
  Future<OcrResult> extractText(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'pdf') {
      return extractTextFromPdf(file);
    } else if (['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension)) {
      return extractTextFromImage(file);
    }
    throw OcrException('Unsupported file type: $extension');
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

  String _cleanText(String raw) {
    return raw
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'[^\x20-\x7E\n]'), '')
        .trim();
  }

  void dispose() {
    _textRecognizer.close();
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
