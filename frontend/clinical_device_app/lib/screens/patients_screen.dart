import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/role_config.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchCtrl = TextEditingController();
  String? _search;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  LinearGradient _getAvatarGradient(String name) {
    final hash = name.hashCode;
    final index = hash.abs() % 4;
    final gradients = [
      AppTheme.primaryGradient,
      AppTheme.blueGradient,
      AppTheme.greenGradient,
      const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
    ];
    return gradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).valueOrNull?.role ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!RoleConfig.canManagePatients(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patients')),
        body: const Center(
          child: EmptyView(
            message: 'Your role cannot access patient management.',
            icon: Icons.lock_outline_rounded,
          ),
        ),
      );
    }

    final patientsAsync = ref.watch(patientsProvider(_search));

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Registry (EMR)')),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.glowShadow(AppTheme.clinicalPrimary, opacity: 0.35, blur: 12),
        ),
        child: FloatingActionButton(
          onPressed: () => _showPatientDialog(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Elegant Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search patient directory by name or MRN...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = null);
                          },
                        )
                      : null,
                ),
                onSubmitted: (v) => setState(() => _search = v.isEmpty ? null : v),
                onChanged: (v) {
                  // Keep UI updated for suffix clear icon state
                  if (v.isEmpty && _search != null) {
                    setState(() => _search = null);
                  } else {
                    setState(() {});
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: patientsAsync.when(
              loading: () => const LoadingView(message: 'Querying clinical EMR database...'),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(patientsProvider(_search)),
              ),
              data: (patients) {
                if (patients.isEmpty) {
                  return const EmptyView(
                    message: 'No patient profiles match the search criteria.',
                    icon: Icons.person_search_rounded,
                  );
                }
                return ListView.builder(
                  itemCount: patients.length,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemBuilder: (context, i) {
                    final p = patients[i];
                    final initial = p.name.trim().isNotEmpty ? p.name.trim()[0].toUpperCase() : 'P';
                    final avatarGrad = _getAvatarGradient(p.name);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            // Custom Initials HSL-gradient Avatar
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: avatarGrad,
                                boxShadow: AppTheme.glowShadow(avatarGrad.colors.first, opacity: 0.25, blur: 8),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            // Patient Info Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          letterSpacing: -0.2,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.clinicalPrimary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'MRN: ${p.mrn}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.clinicalPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'DOB: ${DateFormat.yMMMd().format(p.dateOfBirth)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Quick Action Buttons
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded),
                              iconSize: 26,
                              color: AppTheme.clinicalPrimary,
                              tooltip: 'Modify Profile',
                              onPressed: () => _showPatientDialog(context, patient: p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPatientDialog(BuildContext context, {PatientModel? patient}) async {
    final nameCtrl = TextEditingController(text: patient?.name ?? '');
    final mrnCtrl = TextEditingController(text: patient?.mrn ?? '');
    var dob = patient?.dateOfBirth ?? DateTime(1990, 1, 1);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(patient == null ? 'Register New Patient' : 'Edit Patient Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: mrnCtrl,
                decoration: const InputDecoration(labelText: 'Medical Record Number (MRN)', prefixIcon: Icon(Icons.badge_rounded)),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15), width: 1.5),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dob,
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          dob = picked;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'DOB: ${DateFormat.yMMMd().format(dob)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  final model = PatientModel(
                    patientId: patient?.patientId ?? '',
                    name: nameCtrl.text,
                    dateOfBirth: dob,
                    mrn: mrnCtrl.text,
                  );
                  await ref.read(apiServiceProvider).savePatient(
                        model,
                        isUpdate: patient != null,
                      );
                  ref.invalidate(patientsProvider(_search));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
