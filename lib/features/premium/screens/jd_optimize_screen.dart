import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_hire/features/premium/widgets/preminum_shared_widget.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/resume_pdf_service.dart';
import '../../../providers/premium_providers.dart';
import '../../../providers/resume_context_provider.dart';

class JdOptimizeScreen extends ConsumerStatefulWidget {
  final String resumeText;
  final String userName;
  final String userEmail;

  const JdOptimizeScreen({
    super.key,
    this.resumeText = '',
    required this.userName,
    required this.userEmail,
  });

  @override
  ConsumerState<JdOptimizeScreen> createState() => _JdOptimizeScreenState();
}

class _JdOptimizeScreenState extends ConsumerState<JdOptimizeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _jdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _jdController.dispose();
    super.dispose();
  }

  void _startOptimize() {
    if (_jdController.text.trim().length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please paste a full job description (at least 50 characters)',
          ),
        ),
      );
      return;
    }
    final text = widget.resumeText.trim().length > 50
        ? widget.resumeText
        : ref.read(resumeContextProvider).text;
    ref
        .read(jdOptimizeProvider.notifier)
        .optimize(resumeText: text, jobDescription: _jdController.text.trim());
  }

  Future<void> _handleUnlock() async {
    if (_jdController.text.trim().length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste the job description first')),
      );
      return;
    }
    final paid = await PaywallSheet.show(
      context,
      plan: PaymentPlan.jdOptimize,
      userEmail: widget.userEmail,
      userName: widget.userName,
    );
    if (paid && mounted) {
      await ref.read(unlockProvider.notifier).unlock('jd_optimize');
      _startOptimize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jdOptimizeProvider);
    final unlocked = ref.watch(unlockProvider).contains('jd_optimize');

    return Scaffold(
      appBar: AppBar(
        title: const Text('JD Optimization'),
        actions: [
          if (unlocked && state.result != null)
            _JdPdfButton(
              resumeText: state.result!.optimizedText,
              name: widget.userName,
            ),
        ],
        bottom: unlocked && state.result != null
            ? TabBar(
                controller: _tab,
                isScrollable: true,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                tabs: const [
                  Tab(text: 'Optimized Resume'),
                  Tab(text: 'Changes'),
                  Tab(text: 'Keywords Added'),
                ],
              )
            : null,
      ),
      body: unlocked && state.result != null
          ? _resultBody(state)
          : _inputBody(state),
    );
  }

  Widget _inputBody(JdOptimizeState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.manage_search, color: Colors.white, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JD Auto Optimization',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Paste JD → resume gets auto-tailored with the right keywords',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // JD input
          const Text(
            'Paste Job Description',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jdController,
            maxLines: 10,
            decoration: InputDecoration(
              hintText:
                  'Paste the full job description here…\n\nWe\'ll extract keywords and optimize your resume to match.',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_jdController.text.length} characters · Minimum 50 required',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          // Locked features
          _JdFeatureList(),
          const SizedBox(height: 24),
          // CTA
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: state.isLoading ? null : _handleUnlock,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: state.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.manage_search, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Optimize for This JD · ${PaymentPlan.jdOptimize.displayPrice}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBody(JdOptimizeState state) {
    if (state.isLoading) {
      return const PremiumLoadingView(
        message: 'Optimizing resume for this job…',
      );
    }
    if (state.error != null) {
      return PremiumErrorView(error: state.error!, onRetry: _startOptimize);
    }

    final result = state.result!;
    return TabBarView(
      controller: _tab,
      children: [
        // Tab 1: Optimized text
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ATS Boost indicator
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: AppTheme.success,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated ATS Boost',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.success,
                          ),
                        ),
                        Text(
                          '+${result.estimatedAtsBoost} points',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Optimized Resume',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: result.optimizedText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied!')),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.copy,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    SelectableText(
                      result.optimizedText,
                      style: const TextStyle(fontSize: 12, height: 1.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Tab 2: Changes
        ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: result.linesChanged.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final parts = result.linesChanged[i].split(' → ');
            final before = parts.length > 0
                ? parts[0].replaceFirst('BEFORE: ', '')
                : '';
            final after = parts.length > 1
                ? parts[1].replaceFirst('AFTER: ', '')
                : '';
            return BeforeAfterCard(before: before, after: after);
          },
        ),
        // Tab 3: Keywords
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${result.keywordsAdded.length} keywords embedded from JD',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.keywordsAdded
                    .map(
                      (k) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          k,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JdFeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      'Extracts all keywords + skills from JD',
      'Naturally embeds them into your bullets',
      'Adjusts summary to match JD language',
      'Shows estimated ATS score boost',
      'Download optimized resume as PDF',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What happens:',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF7C3AED),
                  size: 17,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(i, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JdPdfButton extends ConsumerWidget {
  final String resumeText;
  final String name;
  const _JdPdfButton({required this.resumeText, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jdOptimizeProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: state.isGeneratingPdf
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                await ref
                    .read(jdOptimizeProvider.notifier)
                    .generatePdf(resumeText: resumeText, name: name);
                final path = ref.read(jdOptimizeProvider).pdfPath;
                if (path != null && context.mounted) {
                  ResumePdfService().sharePdf(path);
                }
              },
            ),
    );
  }
}
