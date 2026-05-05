// Web stub — ML Kit is not available on web.
// This file satisfies the conditional import on web builds.

class TextRecognitionScript {
  static const latin = TextRecognitionScript._();
  const TextRecognitionScript._();
}

class TextRecognizer {
  TextRecognizer({required TextRecognitionScript script});
  Future<RecognizedText> processImage(dynamic image) async => RecognizedText();
  void close() {}
}

class RecognizedText {
  final List<dynamic> blocks = [];
  final String text = '';
}

class InputImage {
  static InputImage fromFile(dynamic file) => InputImage._();
  const InputImage._();
}
