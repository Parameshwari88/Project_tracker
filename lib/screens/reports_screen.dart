import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../providers.dart';
import '../report/report_service.dart';
import '../util.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
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

  Future<void> _generate(List<Project> projects, {required bool share}) async {
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
      if (share) {
        await shareReport(bytes, key);
      } else {
        final saved = await downloadReport(bytes, key);
        if (saved && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Report saved to your phone')));
        }
      }
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
      builder: (pl) => ResponsiveBody(
        maxWidth: 600,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          GradientHeader(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.table_chart_rounded, color: Colors.white, size: 32),
              const SizedBox(height: 10),
              const Text('Monthly report',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Excel file with one sheet per project and a summary.',
                  style: TextStyle(color: Colors.white70)),
            ]),
          ),
          const SectionTitle('Choose month'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _shift(-1)),
                Text(DateFormat('MMMM yyyy').format(_month),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                IconButton(
                    icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _shift(1)),
              ]),
            ),
          ),
          const SectionTitle('Project'),
          DropdownButtonFormField<String?>(
            initialValue: pl.any((p) => p.id == _projectId) ? _projectId : null,
            isExpanded: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.folder_rounded)),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All projects')),
              for (final p in pl) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _projectId = v),
          ),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _generate(pl, share: false),
                icon: _busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded),
                label: Text(_busy ? 'Building…' : 'Download to phone'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 52,
              height: 52,
              child: IconButton.filledTonal(
                tooltip: 'Share',
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _busy ? null : () => _generate(pl, share: true),
                icon: const Icon(Icons.share_rounded),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Text(
            'Download saves the .xlsx where you choose (for example Downloads). Share sends it to WhatsApp, email and other apps.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }
}
