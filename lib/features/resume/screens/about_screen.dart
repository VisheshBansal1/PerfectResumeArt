import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';

/// About screen — introduces the Perfect Resume Art app and EnquSoft, the
/// studio that builds it. Purely static/informational, so no providers
/// are needed here.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // TODO: wire this to the real build version (e.g. via package_info_plus)
  // if you want it to stay in sync automatically instead of being hardcoded.
  static const String _appVersion = '1.0.0';

  static const List<_ServiceItem> _services = [
    _ServiceItem(Icons.smartphone_rounded, 'Mobile App Development'),
    _ServiceItem(Icons.language_rounded, 'Website Development'),
    _ServiceItem(Icons.web_rounded, 'Web Application Development'),
    _ServiceItem(Icons.extension_rounded, 'Custom Software Solutions'),
    _ServiceItem(Icons.palette_rounded, 'UI/UX Design'),
    _ServiceItem(Icons.shopping_cart_rounded, 'E-commerce Solutions'),
    _ServiceItem(Icons.business_center_rounded, 'Business Management Systems'),
    _ServiceItem(Icons.hub_rounded, 'API Integration'),
    _ServiceItem(Icons.build_rounded, 'Software Maintenance & Support'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppHero(),
            const SizedBox(height: 26),
            _buildAppDescription(context),
            const SizedBox(height: 20),
            _buildFeatureGrid(),
            const SizedBox(height: 32),
            _buildSectionDivider(context, 'Who Builds It'),
            const SizedBox(height: 20),
            _buildEnquSoftCard(),
            const SizedBox(height: 22),
            _buildServicesSection(),
            const SizedBox(height: 22),
            _buildContactCta(context),
            const SizedBox(height: 32),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHero() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.badge_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Perfect Resume Art',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'AI-powered resume analysis, built to get you shortlisted',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey[500],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version $_appVersion',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppDescription(BuildContext context) {
    return Text(
      'Perfect Resume Art scores your resume the way both a recruiter and an '
      'ATS bot would, then shows you exactly what to fix. Match it against a '
      'job description, discover roles with our AI Job Finder, or get a '
      'second opinion from a real reviewer.',
      style: TextStyle(
        fontSize: 14,
        height: 1.55,
        color: AppTheme.textMain(context),
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return Column(
      children: [
        // Wrapped in IntrinsicHeight: this Row uses crossAxisAlignment.stretch
        // but lives inside a SingleChildScrollView, so its incoming height
        // constraint is unbounded. Stretch alone would try to give each
        // _FeatureTile a tight *infinite* height and crash layout.
        // IntrinsicHeight measures the tallest child first and hands the Row
        // a real, finite height to stretch against.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FeatureTile(
                icon: Icons.grading_rounded,
                title: 'ATS Score Analysis',
                subtitle: 'See where you stand against real ATS systems',
                color: AppTheme.primary,
              ),
              const SizedBox(width: 12),
              _FeatureTile(
                icon: Icons.work_rounded,
                title: 'AI Job Finder',
                subtitle: 'Live roles matched to your resume',
                color: AppTheme.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FeatureTile(
                icon: Icons.edit_note_rounded,
                title: 'AI Resume Builder',
                subtitle: 'Build or fix your resume with AI guidance',
                color: Colors.purple,
              ),
              const SizedBox(width: 12),
              _FeatureTile(
                icon: Icons.verified_rounded,
                title: 'Human Expert Review',
                subtitle: 'A real reviewer gives a second opinion',
                color: AppTheme.success,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionDivider(BuildContext context, String label) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.border(context))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted(context),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.border(context))),
      ],
    );
  }

  Widget _buildEnquSoftCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.code_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'EnquSoft',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'EnquSoft builds high-quality digital products for businesses and '
            'startups — mobile apps, websites, web apps, and custom software. '
            'Perfect Resume Art is one of our own products, built end-to-end '
            'with modern tools and industry best practices.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What We Build',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _services.map((s) => _ServiceChip(item: s)).toList(),
        ),
      ],
    );
  }

  Widget _buildContactCta(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(
          AppTheme.isDark(context) ? 0.08 : 0.06,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Have an Idea?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You bring the idea, we build the solution — startup, business '
            'website, mobile app, or enterprise software.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _copyEmail(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, size: 17, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'enqusoft@gmail.com',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textMain(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: AppTheme.textMuted(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push(AppRoutes.contactUs),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Get in Touch',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Made with ',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              const Icon(
                Icons.favorite_rounded,
                size: 13,
                color: Colors.redAccent,
              ),
              Text(
                ' by EnquSoft',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\u00a9 ${DateTime.now().year} EnquSoft. All rights reserved.',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: 'enqusoft@gmail.com'));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String label;
  const _ServiceItem(this.icon, this.label);
}

class _ServiceChip extends StatelessWidget {
  final _ServiceItem item;
  const _ServiceChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12.5,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
