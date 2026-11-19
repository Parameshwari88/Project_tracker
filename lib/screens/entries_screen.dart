import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';
import '../util.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';

String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

class EntriesTab extends ConsumerStatefulWidget {
  const EntriesTab({super.key});

  @override
  ConsumerState<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends ConsumerState<EntriesTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _open([WorkEntry? e]) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => EntryFormScreen(entry: e)));
  }

  @override
  Widget build(BuildContext context) {
    final key = monthKey(_month);
    final entries = ref.watch(entriesProvider(key));
    final projects = ref.watch(projectsProvider).valueOrNull ?? const <Project>[];
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
    final pName = {for (final p in projects) p.id: p.name};
    final mName = {for (final m in members) m.id: m.name};

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New entry'),
      ),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
          Text(DateFormat('MMMM yyyy').format(_month),
              style: Theme.of(context).textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
        ]),
        Expanded(
          child: AsyncBody<List<WorkEntry>>(
            value: entries,
            onRetry: () => ref.invalidate(entriesProvider(key)),
            builder: (list) {
              if (list.isEmpty) return const EmptyState('No entries this month. Tap + to add one.');
              final sorted = [...list]
                ..sort((a, b) => '${b.date} ${b.start}'.compareTo('${a.date} ${a.start}'));
              final byDay = <String, List<WorkEntry>>{};
              for (final e in sorted) {
                byDay.putIfAbsent(e.date, () => []).add(e);
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(entriesProvider(key).future),
                child: ResponsiveBody(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
                    for (final day in byDay.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                        child: Row(children: [
                          Expanded(
                            child: Text(DateFormat('EEEE, d MMM').format(parseDate(day.key)),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${day.value.fold<double>(0, (s, e) => s + hoursBetween(e.start, e.end)).toStringAsFixed(1)} h',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ]),
                      ),
                      for (final e in day.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: InitialAvatar(mName[e.memberId] ?? '?', size: 40),
                              title: Text(mName[e.memberId] ?? '(deleted member)',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${pName[e.projectId] ?? '(deleted project)'}\n${e.start} – ${e.end}${e.notes.isEmpty ? '' : ' · ${e.notes}'}'),
                              isThreeLine: true,
                              trailing: Text(
                                  '${hoursBetween(e.start, e.end).toStringAsFixed(1)} h',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 15)),
                              onTap: () => _open(e),
                            ),
                          ),
                        ),
                    ],
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({super.key, this.entry});
  final WorkEntry? entry;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  late DateTime _date = widget.entry == null ? DateTime.now() : parseDate(widget.entry!.date);
  late TimeOfDay _start =
      widget.entry == null ? const TimeOfDay(hour: 9, minute: 0) : parseTime(widget.entry!.start);
  late TimeOfDay _end =
      widget.entry == null ? const TimeOfDay(hour: 17, minute: 0) : parseTime(widget.entry!.end);
  late final _notes = TextEditingController(text: widget.entry?.notes);
  String? _projectId;
  String? _memberId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _projectId = widget.entry?.projectId;
    _memberId = widget.entry?.memberId;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_projectId == null || _memberId == null) {
      setState(() => _error = 'Choose a project and a member.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final old = widget.entry;
      final e = WorkEntry(
        id: old?.id ?? const Uuid().v4(),
        projectId: _projectId!,
        memberId: _memberId!,
        date: fmtDate(_date),
        start: fmtTime(_start),
        end: fmtTime(_end),
        notes: _notes.text.trim(),
      );
      await ref.read(repoProvider).saveEntry(e);
      ref.invalidate(entriesProvider(monthKey(_date)));
      if (old != null) ref.invalidate(entriesProvider(old.date.substring(0, 7)));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this entry?')) return;
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).deleteEntry(widget.entry!.id);
      ref.invalidate(entriesProvider(widget.entry!.date.substring(0, 7)));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final members = ref.watch(membersProvider);
    final hours = hoursBetween(fmtTime(_start), fmtTime(_end));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'New entry' : 'Edit entry'),
        actions: [
          if (widget.entry != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
        ],
      ),
      body: AsyncBody<List<Project>>(
        value: projects,
        onRetry: () => ref.invalidate(projectsProvider),
        builder: (pl) => AsyncBody<List<Member>>(
          value: members,
          onRetry: () => ref.invalidate(membersProvider),
          builder: (ml) {
            if (pl.isEmpty || ml.isEmpty) {
              return const EmptyState('Add at least one project and one member first.');
            }
            return ResponsiveBody(
              maxWidth: 600,
              child: ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                initialValue: pl.any((p) => p.id == _projectId) ? _projectId : null,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Project *', prefixIcon: Icon(Icons.folder_rounded)),
                items: [for (final p in pl) DropdownMenuItem(value: p.id, child: Text(p.name))],
                onChanged: (v) => setState(() => _projectId = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: ml.any((m) => m.id == _memberId) ? _memberId : null,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Member *', prefixIcon: Icon(Icons.person_rounded)),
                items: [for (final m in ml) DropdownMenuItem(value: m.id, child: Text(m.name))],
                onChanged: (v) => setState(() => _memberId = v),
              ),
              const SizedBox(height: 14),
              _PickTile(
                icon: Icons.calendar_month_rounded,
                label: 'Date',
                value: DateFormat('EEE, d MMM yyyy').format(_date),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _PickTile(
                    icon: Icons.login_rounded,
                    label: 'In time',
                    value: _start.format(context),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _start);
                      if (t != null) setState(() => _start = t);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickTile(
                    icon: Icons.logout_rounded,
                    label: 'Out time',
                    value: _end.format(context),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _end);
                      if (t != null) setState(() => _end = t);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              GradientHeader(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.timer_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text('Total hours', style: TextStyle(color: Colors.white70)),
                  const Spacer(),
                  Text(hours.toStringAsFixed(2),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(
                    labelText: 'Notes', prefixIcon: Icon(Icons.notes_rounded)),
                maxLines: 2,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save entry'),
              ),
            ]),
            );
          },
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile(
      {required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          child: Text(value, style: const TextStyle(fontSize: 16)),
        ),
      );
}
