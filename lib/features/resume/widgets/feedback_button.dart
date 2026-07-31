// lib/features/resume/widgets/feedback_button.dart
//
// Place this file at: lib/features/resume/widgets/feedback_button.dart
//
// Usage: already embedded in the home_screen.dart as a Positioned overlay.
// The button shows a chat bubble in the bottom-left corner. Tapping it opens
// a bottom sheet where users can rate the app + leave a suggestion.
// Submissions are stored in Firestore at /feedback/{docId}.
//
// Firebase structure added:
//   /feedback/{auto_id}
//     message: String
//     rating: int (1-5)
//     createdAt: Timestamp
//     uid: String? (null if anonymous)
//     appVersion: String

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';

class FeedbackButton extends StatelessWidget {
  const FeedbackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Suggest an improvement',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFeedbackSheet(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💬', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  'Suggest Improvement',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FeedbackSheet(),
    );
  }
}

// ── Bottom Sheet ─────────────────────────────────────────────────────────────

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _rating = 0;
  final _controller = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (_rating == 0 && message.isEmpty) {
      setState(() => _error = 'Please rate the app or write a suggestion.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'rating': _rating,
        'message': message,
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0', // bump this when you release updates
      });

      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Couldn\'t send — try again.';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('🎉', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 14),
      const Text(
        'Thanks! We read every single one.',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        'Your suggestion helps us make the app better for everyone.',
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ),
    ],
  );

  Widget _buildForm() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Handle
      Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const Text(
        '💬  Share Your Thoughts',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
      ),
      const SizedBox(height: 4),
      Text(
        'Something missing? Something great? Tell us — no suggestion is too small.',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
      ),
      const SizedBox(height: 20),

      // Star rating
      const Text(
        'How would you rate the app?',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,color: Colors.black),
      ),
      const SizedBox(height: 10),
      Row(
        children: List.generate(5, (i) {
          final filled = i < _rating;
          return GestureDetector(
            onTap: () => setState(() => _rating = i + 1),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  key: ValueKey(filled),
                  size: 36,
                  color: filled ? const Color(0xFFFFA726) : Colors.grey[300],
                ),
              ),
            ),
          );
        }),
      ),

      const SizedBox(height: 18),

      // Message
      const Text(
        'What would you improve?',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _controller,
        maxLines: 4,
        maxLength: 500,
        decoration: InputDecoration(
          hintText:
              'e.g. "I wish there was a dark mode" or "The PDF generation crashed for me..."',
          hintStyle: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.6),
            fontSize: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary),
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),

      if (_error != null) ...[
        const SizedBox(height: 6),
        Text(
          _error!,
          style: TextStyle(fontSize: 12, color: AppTheme.error),
        ),
      ],

      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Send Feedback',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ),
    ],
  );
}