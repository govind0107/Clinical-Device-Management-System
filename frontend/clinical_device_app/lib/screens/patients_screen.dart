import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/role_config.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_client.dart';
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

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).valueOrNull?.role ?? '';
    if (!RoleConfig.canManagePatients(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patients')),
        body: const Center(child: Text('Your role cannot access patient management.')),
      );
    }

    final patientsAsync = ref.watch(patientsProvider(_search));

    return Scaffold(
      appBar: AppBar(title: const Text('Patients')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPatientDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or MRN',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = null);
                  },
                ),
              ),
              onSubmitted: (v) => setState(() => _search = v.isEmpty ? null : v),
            ),
          ),
          Expanded(
            child: patientsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(patientsProvider(_search)),
              ),
              data: (patients) {
                if (patients.isEmpty) {
                  return const EmptyView(message: 'No patients found.');
                }
                return ListView.separated(
                  itemCount: patients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = patients[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text('MRN ${p.mrn} • DOB ${DateFormat.yMMMd().format(p.dateOfBirth)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showPatientDialog(context, patient: p),
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
      builder: (ctx) => AlertDialog(
        title: Text(patient == null ? 'Add patient' : 'Edit patient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: mrnCtrl, decoration: const InputDecoration(labelText: 'MRN')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: dob,
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (picked != null) dob = picked;
              },
              child: Text('DOB: ${DateFormat.yMMMd().format(dob)}'),
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
    );
  }
}
