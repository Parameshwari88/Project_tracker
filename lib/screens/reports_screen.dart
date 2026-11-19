import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';
import '../report/report_service.dart';
import '../util.dart';
import '../widgets/async_view.dart';
import 'entries_screen.dart' show monthKey;

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _projectId; // null = all projects
  bool _busy = false;

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _generate(List<Project> projects) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repoProvider);
      final key = monthKey(_month);
      final entries = await repo.entries(month: key);
      final members = await repo.members();
      final filtered =
          _projectId == null ? entries : entries.where((e) => e.projectId == _projectId).toList();
      final selected =
          _projectId == null ? projects : projects.where((p) => p.id == _projectId).toList();
      final bytes = buildReportBytes(
          month: key, projects: selected, members: members, entries: filtered);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('No entries for this selection.')));
        }
        return;
      }
      await shareReport(bytes, key);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    return AsyncBody<List<Project>>(
      value: projects,
      onRetry: () => ref.invalidate(projectsProvider),
      builder: (pl) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Monthly report', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
          Text(DateFormat('MMMM yyyy').format(_month),
              style: Theme.of(context).textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
        ]),
        DropdownButtonFormField<String?>(
          initialValue: pl.any((p) => p.id == _projectId) ? _projectId : null,
          decoration: const InputDecoration(labelText: 'Project'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All projects')),
            for (final p in pl) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
          ],
          onChanged: (v) => setState(() => _projectId = v),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : () => _generate(pl),
          icon: const Icon(Icons.share),
          label: Text(_busy ? 'Building…' : 'Create and share .xlsx'),
        ),
        const SizedBox(height: 12),
        const Text(
          'The file is built on this phone, handed to the share sheet and not kept afterwards.',
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
