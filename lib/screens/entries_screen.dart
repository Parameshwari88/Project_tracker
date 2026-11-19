import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';
import '../util.dart';
import '../widgets/async_view.dart';

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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add entry',
        onPressed: () => _open(),
        child: const Icon(Icons.add),
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
                child: ListView(children: [
                  for (final day in byDay.entries) ...[
                    Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Expanded(
                          child: Text(DateFormat('EEE, d MMM').format(parseDate(day.key)),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Text('${day.value.fold<double>(0, (s, e) => s + hoursBetween(e.start, e.end)).toStringAsFixed(2)} h'),
                      ]),
                    ),
                    for (final e in day.value)
                      ListTile(
                        title: Text('${mName[e.memberId] ?? '(deleted member)'} · ${pName[e.projectId] ?? '(deleted project)'}'),
                        subtitle: Text(
                            '${e.start} – ${e.end}${e.notes.isEmpty ? '' : '\n${e.notes}'}'),
                        isThreeLine: e.notes.isNotEmpty,
                        trailing: Text('${hoursBetween(e.start, e.end).toStringAsFixed(2)} h'),
                        onTap: () => _open(e),
                      ),
                  ],
                  const SizedBox(height: 80),
                ]),
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
            return ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                initialValue: pl.any((p) => p.id == _projectId) ? _projectId : null,
                decoration: const InputDecoration(labelText: 'Project *'),
                items: [for (final p in pl) DropdownMenuItem(value: p.id, child: Text(p.name))],
                onChanged: (v) => setState(() => _projectId = v),
              ),
              DropdownButtonFormField<String>(
                initialValue: ml.any((m) => m.id == _memberId) ? _memberId : null,
                decoration: const InputDecoration(labelText: 'Member *'),
                items: [for (final m in ml) DropdownMenuItem(value: m.id, child: Text(m.name))],
                onChanged: (v) => setState(() => _memberId = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
                trailing: const Icon(Icons.calendar_today),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('In time'),
                subtitle: Text(fmtTime(_start)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _start);
                  if (t != null) setState(() => _start = t);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Out time'),
                subtitle: Text(fmtTime(_end)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _end);
                  if (t != null) setState(() => _end = t);
                },
              ),
              Text('Hours: ${hours.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
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
                child: Text(_busy ? 'Saving…' : 'Save'),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
