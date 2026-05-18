// lib/core/services/payment_js_bridge_stub.dart
// Mobile/Desktop stub — JS bridge not available on native platforms.
// Razorpay native plugin handles payments on mobile directly.
// This file is only compiled for mobile/desktop builds.

void registerRazorpayCallbacks({
  required void Function(String paymentId, String orderId, String signature) onSuccess,
  required void Function() onDismiss,
}) {
  // No-op on mobile — native Razorpay plugin handles callbacks
}

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
  // No-op on mobile — native plugin opened directly in payment_service.dart
}