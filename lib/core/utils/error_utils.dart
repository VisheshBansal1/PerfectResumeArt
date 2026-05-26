// lib/core/utils/error_utils.dart
//
// Single place that converts any thrown object into a user-readable string.
//
// WHY THIS EXISTS:
// Flutter web minifies class names in release builds. Calling e.toString()
// on an exception whose class was minified returns "Instance of 'minified:a2w'"
// — completely useless to the user. This utility unwraps every known exception
// type before falling back to toString(), and replaces unreadable fallbacks
// with a generic "something went wrong" message.

import 'package:firebase_core/firebase_core.dart';

/// Returns a user-friendly error message from any caught object.
/// Use everywhere instead of e.toString() or '$e'.
///
/// Example:
///   } catch (e) {
///     setState(() => _error = friendlyError(e));
///   }
String friendlyError(Object e, {String fallback = 'Something went wrong. Please try again.'}) {
  // ── Named exception types with .message fields ────────────────────────────
  if (e is FirebaseException) {
    return _firebaseMessage(e);
  }

  // ── Standard Dart exceptions ──────────────────────────────────────────────
  final raw = e.toString();

  // Minified web class — completely unreadable, replace with fallback
  if (raw.contains("Instance of '")) return fallback;

  // Strip common prefixes that add noise
  String msg = raw
    .replaceAll('AiException: ', '')
    .replaceAll('EmailServiceException: ', '')
    .replaceAll('Exception: ', '')
    .replaceAll('FormatException: ', '')
    .trim();

  // Network errors
  if (msg.contains('SocketException') ||
      msg.contains('XMLHttpRequest') ||
      msg.contains('Failed to fetch') ||
      msg.contains('NetworkError') ||
      msg.contains('Connection refused')) {
    return 'Network error. Check your internet connection and try again.';
  }

  // GROQ API specific
  if (msg.contains('API key') || msg.contains('GROQ_API_KEY')) {
    return 'AI service not configured. Contact support.';
  }
  if (msg.contains('timed out')) {
    return 'Request timed out. Please try again.';
  }
  if (msg.contains('Rate limit')) {
    return 'Too many requests. Please wait a moment and try again.';
  }

  // Empty message fallback
  if (msg.isEmpty) return fallback;

  return msg;
}

String _firebaseMessage(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'Permission denied. Please sign in again.';
    case 'not-found':
      return 'Data not found. Please try again.';
    case 'unavailable':
      return 'Service temporarily unavailable. Please try again.';
    case 'network-request-failed':
      return 'Network error. Check your internet connection.';
    case 'unauthenticated':
      return 'Session expired. Please sign in again.';
    default:
      return e.message ?? 'Firebase error (${e.code}). Please try again.';
  }
}
