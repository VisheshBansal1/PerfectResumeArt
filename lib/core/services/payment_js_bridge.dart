// lib/core/services/payment_js_bridge.dart
// Web-only implementation — uses dart:js_interop (Dart 3 standard).
// This file is only compiled for web builds.
// Mobile builds use payment_js_bridge_stub.dart instead.

@JS()
library payment_js_bridge;

import 'dart:js_interop';

// ── Declare the JS functions defined in web/index.html ────────────────────────
// @JS tells Dart these are global window-scope functions.

@JS('registerRazorpayCallbacks')
external void _jsRegisterCallbacks(JSFunction onSuccess, JSFunction onDismiss);

@JS('openRazorpayCheckout')
external void _jsOpenCheckout(
  JSString keyId,
  JSString orderId,
  JSNumber amount,
  JSString currency,
  JSString name,
  JSString description,
  JSString userEmail,
  JSString userName,
);

// ── Public API called by payment_service.dart ─────────────────────────────────

/// Registers Dart callbacks with the JS bridge BEFORE opening Razorpay modal.
/// onSuccess: called with (paymentId, orderId, signature) after payment
/// onDismiss: called when user closes modal without paying
void registerRazorpayCallbacks({
  required void Function(String paymentId, String orderId, String signature) onSuccess,
  required void Function() onDismiss,
}) {
  // Convert Dart functions to JS-callable functions using dart:js_interop
  // .toJS is the Dart 3 replacement for dart:js allowInterop()
  final jsOnSuccess = (
    (JSString paymentId, JSString orderId, JSString signature) {
      onSuccess(paymentId.toDart, orderId.toDart, signature.toDart);
    }
  ).toJS;

  final jsOnDismiss = (() { onDismiss(); }).toJS;

  _jsRegisterCallbacks(jsOnSuccess, jsOnDismiss);
}

/// Opens Razorpay Checkout.js modal — only scalar values, no functions.
void openRazorpayCheckout({
  required String keyId,
  required String orderId,
  required int amount,
  required String currency,
  required String name,
  required String description,
  required String userEmail,
  required String userName,
}) {
  _jsOpenCheckout(
    keyId.toJS,
    orderId.toJS,
    amount.toJS,
    currency.toJS,
    name.toJS,
    description.toJS,
    userEmail.toJS,
    userName.toJS,
  );
}