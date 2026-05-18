import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/providers.dart';
import '../../../providers/resume_context_provider.dart';
import 'package:dotted_border/dotted_border.dart';

class AtsCheckerScreen extends ConsumerStatefulWidget {
  const AtsCheckerScreen({super.key});

  @override
  ConsumerState<AtsCheckerScreen> createState() => _AtsCheckerScreenState();
}

class _AtsCheckerScreenState extends ConsumerState<AtsCheckerScreen> {
  File? _selectedFile;
  String? _fileType;
  List<int>? _selectedBytes;
  String? _selectedFileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: kIsWeb, // bytes only needed on web
    );
    if (result == null) return;

    final picked = result.files.single;
    final ext = (picked.extension ?? '').toLowerCase();
    final allowed = ['pdf', 'jpg', 'jpeg', 'png'];
    if (!allowed.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unsupported file ".$ext". Use PDF, JPG, or PNG.'),
        ),
      );
      return;
    }

    if (kIsWeb) {
      // Web: use bytes — no real file path available
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read file. Please try again.'),
          ),
        );
        return;
      }
      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = picked.name;
        _fileType = ext;
        _selectedFile = null;
      });
      await ref
          .read(resumeUploadProvider.notifier)
          .extractTextFromBytes(
            bytes: Uint8List.fromList(bytes),
            extension: ext,
          );
    } else {
      // Mobile/Desktop: use File path
      if (picked.path == null) return;
      final file = File(picked.path!);
      if (!await file.exists()) return;
      setState(() {
        _selectedFile = file;
        _fileType = ext;
        _selectedBytes = null;
        _selectedFileName = null;
      });
      await ref.read(resumeUploadProvider.notifier).extractText(file);
      // Save to global context
      final extracted = ref.read(resumeUploadProvider).extractedText ?? '';
      if (extracted.isNotEmpty) {
        await ref
            .read(resumeContextProvider.notifier)
            .setResume(extracted, source: 'ats');
      }
    }
  }

  Future<void> _runAtsCheck() async {
    // If no new file but resume is in context, use it directly
    final ctx = ref.read(resumeContextProvider);
    if (_selectedFile == null && _selectedBytes == null && ctx.hasResume) {
      final analysisId = await ref
          .read(resumeUploadProvider.notifier)
          .uploadAndAnalyzeAtsFromText(ctx.text);
      if (analysisId != null && mounted) {
        ref.invalidate(userAnalysesProvider);
        context.go(AppRoutes.analysisResultWithId(analysisId));
      }
      return;
    }

    if (kIsWeb) {
      if (_selectedBytes == null) return;
      final analysisId = await ref
          .read(resumeUploadProvider.notifier)
          .uploadAndAnalyzeAtsFromBytes(
            bytes: Uint8List.fromList(_selectedBytes!),
            fileName: _selectedFileName ?? 'resume',
            extension: _fileType ?? 'pdf',
          );
      if (analysisId != null && mounted) {
        ref.invalidate(userAnalysesProvider);
        context.go(AppRoutes.analysisResultWithId(analysisId));
      }
    } else {
      if (_selectedFile == null) return;
      final analysisId = await ref
          .read(resumeUploadProvider.notifier)
          .uploadAndAnalyzeAts(file: _selectedFile!);
      if (analysisId != null && mounted) {
        ref.invalidate(userAnalysesProvider);
        context.go(AppRoutes.analysisResultWithId(analysisId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(resumeUploadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ATS Checker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            // Show existing resume status
            _buildResumeStatus(),
            const SizedBox(height: 16),
            _buildWhatIsAts(),
            const SizedBox(height: 24),
            _buildChecklist(),
            const SizedBox(height: 28),
            const Text(
              'Upload Your Resume',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildFileDropZone(),
            if (_selectedFile != null || _selectedBytes != null)
              _buildFilePreview(uploadState),
            const SizedBox(height: 24),
            _buildRunButton(uploadState),
            if (uploadState.error != null) _buildError(uploadState.error!),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildResumeStatus() {
    final ctx = ref.watch(resumeContextProvider);
    if (ctx.hasResume) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resume already loaded ✅',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppTheme.success,
                    ),
                  ),
                  Text(
                    'Upload a new one below to re-check, or tap Run ATS Check directly',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Upload your resume PDF below to run the ATS check',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.purple, Colors.purple.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ATS Compatibility Checker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Test if your resume passes Applicant Tracking Systems',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildWhatIsAts() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.purple.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.purple.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.purple, size: 18),
            const SizedBox(width: 8),
            const Text(
              'What is ATS?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'ATS (Applicant Tracking System) is software recruiters use to automatically filter resumes. '
          '75% of resumes are rejected by ATS before a human ever reads them. '
          'Our checker evaluates your resume\'s formatting, keywords, and structure.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _buildChecklist() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'What we check',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      ...const [
        (
          'Formatting & Structure',
          'Clean sections, no complex tables/graphics',
          Icons.format_align_left,
        ),
        (
          'Keywords & Action Verbs',
          'Industry-standard terminology',
          Icons.key_outlined,
        ),
        (
          'Contact Information',
          'Complete and properly placed',
          Icons.contact_page_outlined,
        ),
        (
          'Quantifiable Achievements',
          'Numbers and impact metrics',
          Icons.trending_up,
        ),
        (
          'Section Headers',
          'Standard ATS-readable headers',
          Icons.view_headline,
        ),
        (
          'Length & Consistency',
          'Appropriate length, uniform formatting',
          Icons.straighten,
        ),
      ].map(
        (item) =>
            _ChecklistItem(title: item.$1, subtitle: item.$2, icon: item.$3),
      ),
    ],
  );

  Widget _buildFileDropZone() => GestureDetector(
    onTap: _pickFile,
    child: DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      color: Colors.purple.withOpacity(0.4),
      strokeWidth: 1.5,
      dashPattern: const [8, 4],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 36,
              color: Colors.purple.withOpacity(0.7),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap to select resume',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'PDF, JPG, or PNG',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildFilePreview(dynamic uploadState) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.purple.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.purple.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image_outlined,
              color: Colors.purple,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedFileName ??
                    _selectedFile?.path.split('/').last ??
                    'resume',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFile = null;
                  _selectedBytes = null;
                  _selectedFileName = null;
                  _fileType = null;
                });
                ref.read(resumeUploadProvider.notifier).reset();
              },
              child: Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
            ),
          ],
        ),
        if (uploadState.isExtracting) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(color: Colors.purple),
          const SizedBox(height: 4),
          Text(
            'Reading resume...',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ] else if (uploadState.extractedText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: Colors.purple),
              const SizedBox(width: 4),
              Text(
                'Ready — ${uploadState.extractedText!.split(' ').length} words detected',
                style: const TextStyle(fontSize: 12, color: Colors.purple),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _buildRunButton(dynamic uploadState) {
    final hasContext = ref.read(resumeContextProvider).hasResume;
    final hasFile = _selectedFile != null || _selectedBytes != null;
    final canRun = (hasFile || hasContext) && !uploadState.isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canRun ? _runAtsCheck : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: uploadState.isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.fact_check_outlined),
        label: Text(
          uploadState.isExtracting
              ? 'Reading resume...'
              : uploadState.isUploading
              ? 'Uploading...'
              : uploadState.isAnalyzing
              ? 'Running ATS check...'
              : hasContext && !hasFile
              ? 'Re-run ATS Check on Your Resume'
              : 'Run ATS Check',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildError(String error) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(error, style: TextStyle(color: AppTheme.error, fontSize: 13)),
  );
}

class _ChecklistItem extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.purple, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        Icon(
          Icons.check_circle_outline,
          color: Colors.purple.withOpacity(0.4),
          size: 18,
        ),
      ],
    ),
  );
}
