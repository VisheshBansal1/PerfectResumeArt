import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../job_roles/screens/job_selection_screen.dart';
import 'package:dotted_border/dotted_border.dart';

// ─── Role → Required Skills auto-suggest map ──────────────────────────────────
const Map<String, List<String>> _kRoleSkillsMap = {
  'flutter': [
    'Flutter',
    'Dart',
    'Firebase',
    'REST APIs',
    'BLoC / Riverpod',
    'Material UI',
    'State Management',
    'GetX',
  ],
  'react native': [
    'React Native',
    'JavaScript',
    'TypeScript',
    'Redux / Zustand',
    'REST APIs',
    'Expo',
    'Firebase',
    'Navigation',
  ],
  'react': [
    'React',
    'JavaScript',
    'TypeScript',
    'HTML',
    'CSS',
    'Redux / Zustand',
    'REST APIs',
    'Webpack / Vite',
  ],
  'next.js': [
    'Next.js',
    'React',
    'TypeScript',
    'REST APIs',
    'CSS / Tailwind',
    'Vercel',
    'SEO Optimization',
    'Server-Side Rendering',
  ],
  'nextjs': [
    'Next.js',
    'React',
    'TypeScript',
    'REST APIs',
    'CSS / Tailwind',
    'Vercel',
    'SEO Optimization',
    'Server-Side Rendering',
  ],
  'vue': [
    'Vue.js',
    'JavaScript',
    'TypeScript',
    'Vuex / Pinia',
    'REST APIs',
    'HTML',
    'CSS',
    'Nuxt.js',
  ],
  'angular': [
    'Angular',
    'TypeScript',
    'RxJS',
    'HTML',
    'CSS',
    'NgRx',
    'REST APIs',
    'Angular Material',
  ],
  'android': [
    'Kotlin',
    'Java',
    'Android SDK',
    'Jetpack Compose',
    'Firebase',
    'REST APIs',
    'Coroutines',
    'Room Database',
  ],
  'ios': [
    'Swift',
    'Xcode',
    'UIKit',
    'SwiftUI',
    'Core Data',
    'Firebase',
    'REST APIs',
    'Combine',
  ],
  'node': [
    'Node.js',
    'JavaScript',
    'TypeScript',
    'Express.js',
    'REST APIs',
    'MongoDB',
    'SQL',
    'JWT Auth',
  ],
  'python': [
    'Python',
    'Django / Flask',
    'REST APIs',
    'SQL',
    'Docker',
    'Git',
    'Unit Testing',
    'Celery',
  ],
  'django': [
    'Python',
    'Django',
    'PostgreSQL',
    'REST APIs',
    'Celery',
    'Redis',
    'Docker',
    'Django REST Framework',
  ],
  'fastapi': [
    'Python',
    'FastAPI',
    'PostgreSQL',
    'SQLAlchemy',
    'REST APIs',
    'Docker',
    'Pydantic',
    'Async Programming',
  ],
  'full stack': [
    'JavaScript / TypeScript',
    'React / Vue / Angular',
    'Node.js',
    'SQL / NoSQL',
    'REST APIs',
    'Git',
    'Docker',
    'Authentication',
  ],
  'fullstack': [
    'JavaScript / TypeScript',
    'React / Vue / Angular',
    'Node.js',
    'SQL / NoSQL',
    'REST APIs',
    'Git',
    'Docker',
    'Authentication',
  ],
  'java': [
    'Java',
    'Spring Boot',
    'Maven / Gradle',
    'SQL',
    'REST APIs',
    'Docker',
    'Microservices',
    'JUnit',
  ],
  'spring': [
    'Java',
    'Spring Boot',
    'Spring Security',
    'JPA / Hibernate',
    'REST APIs',
    'Maven',
    'SQL',
    'Docker',
  ],
  'golang': [
    'Go',
    'REST APIs',
    'gRPC',
    'PostgreSQL',
    'Docker',
    'Microservices',
    'Git',
    'Unit Testing',
  ],
  'rust': [
    'Rust',
    'Memory Management',
    'Async Programming',
    'REST APIs',
    'WebAssembly',
    'Docker',
    'Cargo',
  ],
  'data scientist': [
    'Python',
    'Machine Learning',
    'TensorFlow / PyTorch',
    'Pandas',
    'NumPy',
    'SQL',
    'Data Visualization',
    'Scikit-learn',
  ],
  'machine learning': [
    'Python',
    'TensorFlow',
    'PyTorch',
    'Scikit-learn',
    'Pandas',
    'NumPy',
    'Statistics',
    'MLOps',
  ],
  'ml engineer': [
    'Python',
    'TensorFlow',
    'PyTorch',
    'MLOps',
    'Docker',
    'SQL',
    'Apache Spark',
    'Feature Engineering',
  ],
  'data engineer': [
    'Python',
    'SQL',
    'Apache Spark',
    'Kafka',
    'ETL Pipelines',
    'Cloud (AWS / GCP)',
    'Airflow',
    'dbt',
  ],
  'devops': [
    'Docker',
    'Kubernetes',
    'CI/CD',
    'AWS / GCP / Azure',
    'Linux',
    'Terraform',
    'Git',
    'Bash Scripting',
  ],
  'cloud': [
    'AWS / GCP / Azure',
    'Terraform',
    'Docker',
    'Kubernetes',
    'Networking',
    'IAM / Security',
    'CI/CD',
    'Linux',
  ],
  'aws': [
    'AWS EC2 / S3 / Lambda',
    'RDS',
    'IAM',
    'CloudFormation',
    'Docker',
    'Linux',
    'Networking',
    'VPC',
  ],
  'kubernetes': [
    'Kubernetes',
    'Docker',
    'Helm',
    'CI/CD',
    'Linux',
    'AWS / GCP / Azure',
    'Terraform',
    'Service Mesh',
  ],
  'blockchain': [
    'Solidity',
    'Web3.js / Ethers.js',
    'Smart Contracts',
    'Ethereum',
    'DeFi',
    'Hardhat / Truffle',
    'IPFS',
  ],
  'qa': [
    'Test Automation',
    'Selenium / Appium',
    'JIRA',
    'API Testing',
    'Performance Testing',
    'CI/CD',
    'BDD / TDD',
    'Cypress',
  ],
  'ui/ux': [
    'Figma',
    'UI/UX Design',
    'Prototyping',
    'User Research',
    'Design Systems',
    'Adobe XD',
    'Wireframing',
    'Accessibility',
  ],
  'ux': [
    'Figma',
    'User Research',
    'Prototyping',
    'Wireframing',
    'Design Systems',
    'Usability Testing',
    'Information Architecture',
  ],
  'security': [
    'Penetration Testing',
    'Network Security',
    'OWASP',
    'Python',
    'Security Auditing',
    'Linux',
    'Cryptography',
    'SIEM Tools',
  ],
  'backend': [
    'REST APIs',
    'SQL',
    'Authentication',
    'Docker',
    'Git',
    'Caching (Redis)',
    'Microservices',
    'Message Queues',
  ],
  'frontend': [
    'HTML',
    'CSS',
    'JavaScript',
    'TypeScript',
    'React / Vue / Angular',
    'Responsive Design',
    'REST APIs',
    'Accessibility',
  ],
};

/// Returns suggested skills for a given role title, or [] if no match.
List<String> _suggestSkillsForRole(String roleTitle) {
  final lower = roleTitle.trim().toLowerCase();
  if (lower.isEmpty) return [];
  // Sort by key length descending so "react native" matches before "react"
  final sorted = _kRoleSkillsMap.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in sorted) {
    if (lower.contains(key)) return _kRoleSkillsMap[key]!;
  }
  return [];
}

// ──────────────────────────────────────────────────────────────────────────────

class UploadResumeScreen extends ConsumerStatefulWidget {
  const UploadResumeScreen({super.key});

  @override
  ConsumerState<UploadResumeScreen> createState() => _UploadResumeScreenState();
}

class _UploadResumeScreenState extends ConsumerState<UploadResumeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  File? _selectedFile;
  String? _fileType;

  /// Which tab index triggered the last error (so errors don't bleed across tabs)
  int? _errorFromTabIndex;

  // Tab 1: Job Role mode
  JobModel? _selectedJob;

  // Tab 2: Custom Tech mode
  final _customTitleCtrl = TextEditingController();
  final _customDescCtrl = TextEditingController();
  final _customSkillCtrl = TextEditingController();
  final List<String> _customSkills = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Clear errors belonging to the other tab when switching
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_errorFromTabIndex != null &&
            _errorFromTabIndex != _tabController.index) {
          ref.read(resumeUploadProvider.notifier).clearError();
          setState(() => _errorFromTabIndex = null);
        }
      }
    });

    // Rebuild when title text changes → button enable/disable + live suggestions
    _customTitleCtrl.addListener(() => setState(() {}));

    // Jump to Custom Tech tab if launched with extra: 'custom'
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra;
      if (extra is String && extra == 'custom') {
        _tabController.animateTo(1);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customTitleCtrl.dispose();
    _customDescCtrl.dispose();
    _customSkillCtrl.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.single.path == null) return;

      final pickedPath = result.files.single.path!;
      final extension = result.files.single.extension?.toLowerCase() ?? '';

      // ── Validate file type ──────────────────────────────────
      const supported = ['pdf', 'jpg', 'jpeg', 'png'];
      if (!supported.contains(extension)) {
        _showError(
          'Unsupported file type ".$extension".\n'
          'Please upload a PDF, JPG, or PNG file.',
        );
        return;
      }

      final file = File(pickedPath);

      // ── Validate file exists ────────────────────────────────
      if (!await file.exists()) {
        _showError('File not found. Please try selecting it again.');
        return;
      }

      // ── Validate file size ──────────────────────────────────
      final fileSize = await file.length();
      if (fileSize == 0) {
        _showError(
          'The selected file appears to be empty. Please choose a different file.',
        );
        return;
      }
      if (fileSize > 10 * 1024 * 1024) {
        // 10 MB limit
        _showError(
          'File is too large (max 10 MB). Please compress or choose a smaller file.',
        );
        return;
      }

      // ── All checks passed — proceed ─────────────────────────
      setState(() {
        _selectedFile = file;
        _fileType = extension;
        _errorFromTabIndex = null;
      });
      ref.read(resumeUploadProvider.notifier).clearError();
      await ref.read(resumeUploadProvider.notifier).extractText(file);
    } catch (e) {
      // Catches FilePicker errors and any unexpected exceptions
      _showError('Could not open the file. Please try a different file.');
    }
  }

  Future<void> _analyzeJobRole() async {
    if (_selectedFile == null) {
      _showError('Please select a resume file first.');
      return;
    }
    if (_selectedJob == null) {
      _showError('Please select a job role to analyze your resume match.');
      return;
    }
    setState(() => _errorFromTabIndex = 0);
    final analysisId = await ref
        .read(resumeUploadProvider.notifier)
        .uploadAndAnalyze(file: _selectedFile!, selectedJob: _selectedJob!);
    if (analysisId != null && mounted) {
      ref.invalidate(userAnalysesProvider);
      context.go(AppRoutes.analysisResultWithId(analysisId));
    }
  }

  Future<void> _analyzeCustomTech() async {
    if (_selectedFile == null) {
      _showError('Please select a resume file first.');
      return;
    }
    if (_customTitleCtrl.text.trim().isEmpty) {
      _showError('Please enter a job title or tech stack name.');
      return;
    }
    if (_customSkills.isEmpty) {
      _showError('Please add at least one required skill or technology.');
      return;
    }
    setState(() => _errorFromTabIndex = 1);
    final analysisId = await ref
        .read(resumeUploadProvider.notifier)
        .uploadAndAnalyzeCustom(
          file: _selectedFile!,
          jobTitle: _customTitleCtrl.text.trim(),
          requiredSkills: List.from(_customSkills),
          description: _customDescCtrl.text.trim(),
        );
    if (analysisId != null && mounted) {
      ref.invalidate(userAnalysesProvider);
      context.go(AppRoutes.analysisResultWithId(analysisId));
    }
  }

  Future<void> _selectJob() async {
    final job = await showModalBottomSheet<JobModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const JobSelectionBottomSheet(),
    );
    if (job != null) setState(() => _selectedJob = job);
  }

  void _addCustomSkill() {
    final val = _customSkillCtrl.text.trim();
    if (val.isNotEmpty && !_customSkills.contains(val)) {
      setState(() => _customSkills.add(val));
      _customSkillCtrl.clear();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(resumeUploadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyze Resume'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.work_outline, size: 18), text: 'By Job Role'),
            Tab(icon: Icon(Icons.code_outlined, size: 18), text: 'Custom Tech'),
          ],
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJobRoleTab(uploadState),
          _buildCustomTechTab(uploadState),
        ],
      ),
    );
  }

  // ─── Tab 1: Job Role ──────────────────────────────────────────────────────

  Widget _buildJobRoleTab(ResumeUploadState uploadState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            'Match your resume to an admin-created job role for full AI scoring.',
            AppTheme.primary,
            Icons.info_outline,
          ),
          const SizedBox(height: 20),
          _buildStepHeader(
            1,
            'Select your resume',
            'PDF, JPG or PNG',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          _buildFileDropZone(color: AppTheme.primary),
          if (_selectedFile != null) _buildFilePreview(uploadState),
          const SizedBox(height: 24),
          _buildStepHeader(
            2,
            'Select job role',
            'Required — choose the position you\'re targeting',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          _buildJobSelector(),
          if (_selectedJob != null) ...[
            const SizedBox(height: 10),
            _buildJobPreview(),
          ] else ...[
            const SizedBox(height: 10),
            _buildWarningNote(
              'Job role is required to calculate your resume match score.',
            ),
          ],
          const SizedBox(height: 28),
          _buildAnalyzeButton(
            uploadState,
            _analyzeJobRole,
            tabIndex: 0,
            tabColor: AppTheme.primary,
          ),
          if (uploadState.error != null && _errorFromTabIndex == 0)
            _buildError(uploadState.error!),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Tab 2: Custom Tech ───────────────────────────────────────────────────

  Widget _buildCustomTechTab(ResumeUploadState uploadState) {
    final suggestions = _suggestSkillsForRole(_customTitleCtrl.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            'Define your own tech stack and see how well your resume fits it.',
            AppTheme.accent,
            Icons.code_outlined,
          ),
          const SizedBox(height: 20),
          _buildStepHeader(
            1,
            'Select your resume',
            'PDF, JPG or PNG',
            color: AppTheme.accent,
          ),
          const SizedBox(height: 12),
          _buildFileDropZone(color: AppTheme.accent),
          if (_selectedFile != null) _buildFilePreview(uploadState),
          const SizedBox(height: 24),
          _buildStepHeader(
            2,
            'Define your tech stack',
            'Required — what technologies to check for',
            color: AppTheme.accent,
          ),
          const SizedBox(height: 12),

          // Role / Tech Name field
          TextField(
            controller: _customTitleCtrl,
            decoration: InputDecoration(
              labelText: 'Role / Tech Name *',
              hintText:
                  'e.g. Flutter Developer, React Engineer, Data Scientist',
              prefixIcon: const Icon(Icons.work_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),

          // Auto-suggest card — only shown when there are matches
          if (suggestions.isNotEmpty) _buildSkillSuggestions(suggestions),

          const SizedBox(height: 14),

          // Description field
          TextField(
            controller: _customDescCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'Describe the context or additional requirements…',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Icon(Icons.description_outlined),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.accent,
                  width: 1.5,
                ),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Skills label
          Row(
            children: [
              Icon(Icons.star_rounded, color: AppTheme.accent, size: 14),
              const SizedBox(width: 6),
              const Text(
                'Required Technologies / Skills *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Skill input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _customSkillCtrl,
                  decoration: InputDecoration(
                    hintText: 'Type a skill and press +',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppTheme.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addCustomSkill(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                width: 46,
                child: ElevatedButton(
                  onPressed: _addCustomSkill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Icon(Icons.add, size: 20),
                ),
              ),
            ],
          ),

          // Added skill chips
          if (_customSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _customSkills
                  .map(
                    (skill) => Chip(
                      label: Text(
                        skill,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: AppTheme.accent.withOpacity(0.08),
                      side: BorderSide(color: AppTheme.accent.withOpacity(0.3)),
                      deleteIcon: Icon(
                        Icons.close,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      onDeleted: () =>
                          setState(() => _customSkills.remove(skill)),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  )
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Add the technologies you want to check against (e.g. React, Node.js, PostgreSQL)',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],

          const SizedBox(height: 28),
          _buildAnalyzeButton(
            uploadState,
            _analyzeCustomTech,
            tabIndex: 1,
            tabColor: AppTheme.accent,
          ),
          if (uploadState.error != null && _errorFromTabIndex == 1)
            _buildError(uploadState.error!),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Auto-Suggest Skills Card ──────────────────────────────────────────────

  Widget _buildSkillSuggestions(List<String> suggestions) {
    final unadded = suggestions
        .where((s) => !_customSkills.contains(s))
        .toList();

    // All skills already added → show confirmation banner
    if (unadded.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.success.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.success.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppTheme.success,
              size: 15,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'All suggested skills for this role are already added ✓',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high, color: AppTheme.accent, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Suggested skills for this role',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    for (final s in unadded) {
                      if (!_customSkills.contains(s)) _customSkills.add(s);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'Add All',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions.map((skill) {
              final isAdded = _customSkills.contains(skill);
              return GestureDetector(
                onTap: isAdded
                    ? null
                    : () => setState(() => _customSkills.add(skill)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isAdded
                        ? Colors.grey.shade100
                        : AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isAdded
                          ? Colors.grey.shade300
                          : AppTheme.accent.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdded ? Icons.check : Icons.add,
                        size: 12,
                        color: isAdded ? Colors.grey.shade400 : AppTheme.accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        skill,
                        style: TextStyle(
                          fontSize: 11,
                          color: isAdded
                              ? Colors.grey.shade400
                              : AppTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ────────────────────────────────────────────────────────

  Widget _buildInfoBanner(String text, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _buildStepHeader(
    int step,
    String title,
    String subtitle, {
    required Color color,
  }) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    ],
  );

  Widget _buildFileDropZone({required Color color}) => GestureDetector(
    onTap: _pickFile,
    child: DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      color: color.withOpacity(0.45),
      strokeWidth: 1.5,
      dashPattern: const [8, 4],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: color.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.upload_file_outlined, size: 26, color: color),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap to select file',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Supports PDF, JPG, PNG',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildFilePreview(ResumeUploadState uploadState) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.success.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _fileType == 'pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
              color: AppTheme.success,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedFile!.path.split('/').last,
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
                  _fileType = null;
                  _errorFromTabIndex = null;
                });
                ref.read(resumeUploadProvider.notifier).reset();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
        if (uploadState.isExtracting) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.success.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(AppTheme.success),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Extracting text…',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ] else if (uploadState.extractedText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: AppTheme.success),
              const SizedBox(width: 5),
              Text(
                '${uploadState.extractedText!.split(' ').length} words extracted',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _buildJobSelector() => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: _selectJob,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedJob == null
                ? AppTheme.warning.withOpacity(0.5)
                : AppTheme.borderLight,
            width: _selectedJob == null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: _selectedJob == null
              ? AppTheme.warning.withOpacity(0.02)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.work_outline,
              color: _selectedJob == null ? AppTheme.warning : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedJob == null
                    ? 'Tap to select a job role (required)'
                    : _selectedJob!.title,
                style: TextStyle(
                  color: _selectedJob == null ? AppTheme.warning : null,
                  fontWeight: _selectedJob != null
                      ? FontWeight.w500
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    ),
  );

  Widget _buildJobPreview() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.04),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.checklist_rtl_outlined,
              size: 13,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 5),
            Text(
              'Required Skills',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            if (_selectedJob!.minExperience > 0) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_selectedJob!.minExperience}+ yrs exp',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _selectedJob!.requiredSkills
              .take(8)
              .map(
                (skill) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    skill,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        if (_selectedJob!.requiredSkills.length > 8) ...[
          const SizedBox(height: 4),
          Text(
            '+${_selectedJob!.requiredSkills.length - 8} more required skills',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ],
    ),
  );

  Widget _buildWarningNote(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.warning.withOpacity(0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppTheme.warning),
          ),
        ),
      ],
    ),
  );

  Widget _buildAnalyzeButton(
    ResumeUploadState uploadState,
    VoidCallback onPressed, {
    required int tabIndex,
    required Color tabColor,
  }) {
    final bool canAnalyze;
    if (tabIndex == 0) {
      canAnalyze = _selectedFile != null && _selectedJob != null;
    } else {
      // Reactive check — works because _customTitleCtrl has a setState listener
      canAnalyze =
          _selectedFile != null &&
          _customTitleCtrl.text.trim().isNotEmpty &&
          _customSkills.isNotEmpty;
    }

    final bool isBusy = uploadState.isExtracting || uploadState.isAnalyzing;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canAnalyze && !isBusy ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: tabColor,
          disabledBackgroundColor: tabColor.withOpacity(0.35),
        ),
        icon: isBusy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          uploadState.isExtracting
              ? 'Extracting text…'
              : uploadState.isAnalyzing
              ? 'AI is analyzing…'
              : 'Analyze Resume',
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
      border: Border.all(color: AppTheme.error.withOpacity(0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.error_outline, color: AppTheme.error, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded( 
          child: Text(
            error,
            style: TextStyle(color: AppTheme.error, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
