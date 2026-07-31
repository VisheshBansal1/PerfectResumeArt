import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../providers/resume_context_provider.dart';

/// Compact status card shown whenever a resume is already sitting in the
/// shared context — with explicit Change / Remove actions, matching the
/// pattern already used in the Premium Hub so this looks and behaves the
/// same everywhere a "resume already loaded" state can occur.
///
/// [onChangeRequested] should reveal a [ResumeInputPanel] (or equivalent)
/// so the replacement flow also gets upload + drag-drop + paste, not just
/// a bare file picker.
class LoadedResumeCard extends ConsumerWidget {
  final VoidCallback onChangeRequested;
  final VoidCallback? onRemoved;

  const LoadedResumeCard({super.key, required this.onChangeRequested, this.onRemoved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(resumeContextProvider);
    if (!ctx.hasResume) return const SizedBox.shrink();

    final wordCount = ctx.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final subtitle = [
      if (ctx.fileName.isNotEmpty) ctx.fileName else 'From pasted text',
      '$wordCount words',
      if (ctx.detectedRole.isNotEmpty) ctx.detectedRole,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.success.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resume Loaded ✅',
                        style: TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.success.withOpacity(0.2)),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onChangeRequested,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file_rounded, size: 15, color: AppTheme.success.withOpacity(0.85)),
                        const SizedBox(width: 5),
                        Text(
                          'Change Resume',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.success.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 38, color: AppTheme.success.withOpacity(0.2)),
              Expanded(
                child: InkWell(
                  onTap: () => _confirmRemove(context, ref, onRemoved),
                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, size: 15, color: AppTheme.error.withOpacity(0.75)),
                        const SizedBox(width: 5),
                        Text(
                          'Remove',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.error.withOpacity(0.85)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, VoidCallback? onRemoved) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Resume?'),
        content: const Text(
          'This will clear your uploaded resume from all tools. You can re-upload anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(resumeContextProvider.notifier).clear();
              onRemoved?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resume removed'), duration: Duration(seconds: 2)),
              );
            },
            child: Text('Remove', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
