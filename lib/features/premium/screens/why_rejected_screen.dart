import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/resume_improve_service.dart';
import '../../../providers/premium_providers.dart';
import '../../../providers/resume_context_provider.dart';

class WhyRejectedScreen extends ConsumerStatefulWidget {
  final String resumeText;
  final String jobTitle;

  const WhyRejectedScreen({
    super.key,
    this.resumeText = '',
    this.jobTitle = '',
  });

  @override
  ConsumerState<WhyRejectedScreen> createState() => _WhyRejectedScreenState();
}

class _WhyRejectedScreenState extends ConsumerState<WhyRejectedScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  // String get _effectiveText {
  //   if (widget.resumeText.trim().length > 50) return widget.resumeText;
  //   return ref.read(resumeContextProvider).text;
  // }

  String get _effectiveText {
    if (widget.resumeText.trim().length > 50) return widget.resumeText;
    return ref.read(resumeContextProvider).text;
  }

  void _start() {
    setState(() => _started = true);
    final ctx = ref.read(resumeContextProvider);
    final jobTitle = widget.jobTitle.isNotEmpty
        ? widget.jobTitle
        : ctx.detectedRole;
    ref
        .read(rejectionProvider.notifier)
        .analyze(resumeText: _effectiveText, jobTitle: jobTitle);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rejectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Why You Get Rejected')),
      body: state.isLoading
          ? _buildLoading()
          : state.error != null
          ? _buildError(state.error!)
          : _buildResults(state.reasons),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                size: 40,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Analyzing your resume…',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Getting the brutal truth ready',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppTheme.error),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _start, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<RejectionReason> reasons) {
    if (reasons.isEmpty) return const Center(child: Text('No issues found'));

    // Count by severity
    final critical = reasons.where((r) => r.severity == 'critical').length;
    final high = reasons.where((r) => r.severity == 'high').length;
    final medium = reasons.where((r) => r.severity == 'medium').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.error.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Rejection Analysis',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (critical > 0)
                      _SeverityPill('$critical Critical', AppTheme.error),
                    if (critical > 0) const SizedBox(width: 8),
                    if (high > 0) _SeverityPill('$high High', AppTheme.warning),
                    if (high > 0) const SizedBox(width: 8),
                    if (medium > 0)
                      _SeverityPill('$medium Medium', Colors.orange),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  critical > 0
                      ? 'Your resume has critical issues that are causing automatic rejection. Fix these first.'
                      : 'Your resume has issues that are lowering your ranking. Fix these to stand out.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sort by severity: critical first
          ..._sorted(reasons).map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _RejectionCard(reason: r),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<RejectionReason> _sorted(List<RejectionReason> reasons) {
    final order = {'critical': 0, 'high': 1, 'medium': 2};
    return [...reasons]..sort(
      (a, b) => (order[a.severity] ?? 3).compareTo(order[b.severity] ?? 3),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  final String text;
  final Color color;
  const _SeverityPill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class _RejectionCard extends StatefulWidget {
  final RejectionReason reason;
  const _RejectionCard({required this.reason});

  @override
  State<_RejectionCard> createState() => _RejectionCardState();
}

class _RejectionCardState extends State<_RejectionCard> {
  bool _expanded = false;

  Color get _color {
    switch (widget.reason.severity) {
      case 'critical':
        return AppTheme.error;
      case 'high':
        return AppTheme.warning;
      default:
        return Colors.orange;
    }
  }

  IconData get _icon {
    switch (widget.reason.category.toLowerCase()) {
      case 'metrics':
        return Icons.bar_chart;
      case 'summary':
        return Icons.article;
      case 'projects':
        return Icons.code;
      case 'ats':
        return Icons.fact_check;
      case 'first_impression':
        return Icons.visibility;
      case 'skills_proof':
        return Icons.build;
      default:
        return Icons.warning_amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withOpacity(0.3)),
          color: _color.withOpacity(0.04),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_icon, color: _color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.reason.category,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _color,
                              ),
                            ),
                            const Spacer(),
                            _SeverityPill(
                              widget.reason.severity.toUpperCase(),
                              _color,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.reason.verdict,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 15,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Fix: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppTheme.success,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.reason.fix,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
