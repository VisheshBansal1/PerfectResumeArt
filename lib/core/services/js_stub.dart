// lib/core/services/js_stub.dart
// Stub for dart:js on mobile/desktop builds.
// dart:js only exists on web — this file satisfies the conditional import on mobile.

// ignore_for_file: avoid_classes_with_only_static_members

class JsObject {
  static JsObject jsify(Map<String, dynamic> object) => JsObject._();
  JsObject._();
  operator [](String key) => null;
}

// ignore: non_constant_identifier_names
final context = _JsContext();

class _JsContext {
  dynamic callMethod(String method, [List<dynamic>? args]) => null;
}

T allowInterop<T extends Function>(T f) => f;
