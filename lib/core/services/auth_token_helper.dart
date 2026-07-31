import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// lib/core/services/auth_token_helper.dart
//
// THE BUG: on Flutter Web, right after a fresh page load, Firebase Auth needs
// a moment to restore a signed-in session from IndexedDB. During that brief
// window, `FirebaseAuth.instance.currentUser` is still null — even for a
// user who IS actually logged in.
//
// THE FIX, ROUND 2: the first version of this helper waited on
// `FirebaseAuth.instance.authStateChanges().first`. That stream is a
// broadcast stream already being listened to elsewhere in this app —
// `authStateProvider`, `premium_providers.dart`, and the router's refresh
// listenable all subscribe to it, typically before this helper ever runs.
// A broadcast stream does NOT replay past events to a new, later listener
// — it only delivers events that occur AFTER that listener attaches. So if
// the sign-in event already fired and was delivered to those earlier
// listeners, THIS helper's `.first` would never receive anything and would
// just sit there until an unrelated future auth change (sign-out, token
// refresh) — or, in practice, time out and return null even though the
// user is genuinely signed in.
//
// Polling `currentUser` directly sidesteps that entirely — it doesn't rely
// on stream-subscription timing or replay semantics at all, just repeatedly
// checks the actual current value.
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> getIdTokenSafely() async {
  var current = FirebaseAuth.instance.currentUser;
  if (current != null) {
    try {
      return await current.getIdToken();
    } catch (_) {
      return null;
    }
  }

  // Poll for up to ~3 seconds (20 × 150ms) rather than waiting on a stream
  // event that may never arrive for this particular listener.
  for (var i = 0; i < 20; i++) {
    await Future.delayed(const Duration(milliseconds: 150));
    current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      try {
        return await current.getIdToken();
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}
