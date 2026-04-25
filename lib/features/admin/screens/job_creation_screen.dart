import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../core/router/app_router.dart';

class JobCreationScreen extends ConsumerStatefulWidget {
  const JobCreationScreen({super.key});

  @override
  ConsumerState<JobCreationScreen> createState() => _JobCreationScreenState();
}

class _JobCreationScreenState extends ConsumerState<JobCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _expCtrl = TextEditingController(text: '0');
  final _skillCtrl = TextEditingController();
  final _prefSkillCtrl = TextEditingController();
  final _projectTypeCtrl = TextEditingController();

  final List<String> _requiredSkills = [];
  final List<String> _preferredSkills = [];
  final List<String> _projectTypes = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _expCtrl.dispose();
    _skillCtrl.dispose();
    _prefSkillCtrl.dispose();
    _projectTypeCtrl.dispose();
    super.dispose();
  }

  void _addChip(List<String> list, TextEditingController ctrl) {
    final val = ctrl.text.trim();
    if (val.isNotEmpty && !list.contains(val)) {
      setState(() => list.add(val));
      ctrl.clear();
    }
  }

  void _removeChip(List<String> list, String val) =>
      setState(() => list.remove(val));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiredSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one required skill')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final job = JobModel(
      id: '',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      requiredSkills: List.from(_requiredSkills),
      preferredSkills: List.from(_preferredSkills),
      minExperience: int.tryParse(_expCtrl.text) ?? 0,
      requiredProjectTypes: List.from(_projectTypes),
      createdBy: uid,
      createdAt: DateTime.now(),
    );

    final notifier = ref.read(jobManagementProvider.notifier);
    final id = await notifier.createJob(job);
    if (id != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job role created successfully!')),
      );
      context.canPop() ? context.pop() : context.go(AppRoutes.adminDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(jobManagementProvider);
    final isLoading = jobState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Job Role')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Basic Information'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Job Title *',
                  hintText: 'e.g. Senior Flutter Developer',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Job Description *',
                  hintText: 'Describe responsibilities, goals, team context...',
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().length < 20
                    ? 'Provide a detailed description (20+ chars)'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _expCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Experience (years)',
                  prefixIcon: Icon(Icons.timeline),
                ),
                validator: (v) => int.tryParse(v ?? '') == null
                    ? 'Enter a valid number'
                    : null,
              ),
              const SizedBox(height: 24),
              _sectionLabel('Required Skills *'),
              const SizedBox(height: 8),
              _ChipInput(
                controller: _skillCtrl,
                hint: 'Add skill (e.g. Flutter)',
                chips: _requiredSkills,
                chipColor: AppTheme.primary,
                onAdd: () => _addChip(_requiredSkills, _skillCtrl),
                onRemove: (v) => _removeChip(_requiredSkills, v),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Preferred Skills'),
              const SizedBox(height: 8),
              _ChipInput(
                controller: _prefSkillCtrl,
                hint: 'Add preferred skill',
                chips: _preferredSkills,
                chipColor: Colors.purple,
                onAdd: () => _addChip(_preferredSkills, _prefSkillCtrl),
                onRemove: (v) => _removeChip(_preferredSkills, v),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Required Project Types'),
              const SizedBox(height: 4),
              Text(
                'e.g. "E-commerce app", "REST API", "Machine Learning model"',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              _ChipInput(
                controller: _projectTypeCtrl,
                hint: 'Add project type',
                chips: _projectTypes,
                chipColor: AppTheme.accent,
                onAdd: () => _addChip(_projectTypes, _projectTypeCtrl),
                onRemove: (v) => _removeChip(_projectTypes, v),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Create Job Role'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}

class _ChipInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final List<String> chips;
  final Color chipColor;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _ChipInput({
    required this.controller,
    required this.hint,
    required this.chips,
    required this.chipColor,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: chipColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      if (chips.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: chips
              .map(
                (chip) => Chip(
                  label: Text(
                    chip,
                    style: TextStyle(
                      fontSize: 12,
                      color: chipColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: chipColor.withOpacity(0.08),
                  side: BorderSide(color: chipColor.withOpacity(0.3)),
                  deleteIcon: Icon(Icons.close, size: 14, color: chipColor),
                  onDeleted: () => onRemove(chip),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              )
              .toList(),
        ),
      ],
    ],
  );
}
