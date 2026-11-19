import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';
import '../util.dart';
import '../widgets/async_view.dart';

class ProjectsTab extends ConsumerWidget {
  const ProjectsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(projectsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add project',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ProjectFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: AsyncBody<List<Project>>(
        value: value,
        onRetry: () => ref.invalidate(projectsProvider),
        builder: (list) => list.isEmpty
            ? const EmptyState('No projects yet. Tap + to add one.')
            : RefreshIndicator(
                onRefresh: () => ref.refresh(projectsProvider.future),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text([if (p.client.isNotEmpty) p.client, p.status].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: p))),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.project});
  final Project? project;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.project?.name);
  late final _client = TextEditingController(text: widget.project?.client);
  late final _notes = TextEditingController(text: widget.project?.notes);
  late String _status = widget.project?.status ?? 'active';
  late String _start = widget.project?.startDate ?? '';
  late String _end = widget.project?.endDate ?? '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _client.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final cur = start ? _start : _end;
    final d = await showDatePicker(
      context: context,
      initialDate: cur.isEmpty ? DateTime.now() : parseDate(cur),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => start ? _start = fmtDate(d) : _end = fmtDate(d));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final base = widget.project ?? Project(id: const Uuid().v4(), name: '');
      await ref.read(repoProvider).saveProject(base.copyWith(
            name: _name.text.trim(),
            client: _client.text.trim(),
            status: _status,
            startDate: _start,
            endDate: _end,
            notes: _notes.text.trim(),
          ));
      ref.invalidate(projectsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this project? Its work entries stay but show no project.')) return;
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).deleteProject(widget.project!.id);
      ref.invalidate(projectsProvider);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.project == null ? 'New project' : 'Edit project'),
          actions: [
            if (widget.project != null)
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(controller: _client, decoration: const InputDecoration(labelText: 'Client')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'hold', child: Text('On hold')),
                DropdownMenuItem(value: 'done', child: Text('Done')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'active'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(_start.isEmpty ? 'Not set' : _start),
              trailing: _start.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _start = '')),
              onTap: () => _pick(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End date'),
              subtitle: Text(_end.isEmpty ? 'Not set' : _end),
              trailing: _end.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _end = '')),
              onTap: () => _pick(false),
            ),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ]),
        ),
      );
}

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final Project project;

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  late Project _project = widget.project;
  Set<String>? _selected;
  bool _saving = false;

  Future<void> _edit() async {
    final r = await Navigator.push<Object>(context,
        MaterialPageRoute(builder: (_) => ProjectFormScreen(project: _project)));
    if (!mounted) return;
    if (r == 'deleted') {
      Navigator.pop(context);
    } else if (r == true) {
      final list = await ref.read(projectsProvider.future);
      final updated = list.where((p) => p.id == _project.id);
      if (updated.isNotEmpty && mounted) setState(() => _project = updated.first);
    }
  }

  Future<void> _saveMembers() async {
    setState(() => _saving = true);
    try {
      await ref.read(repoProvider).setProjectMembers(_project.id, _selected!.toList());
      ref.invalidate(projectMemberIdsProvider(_project.id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Team saved')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider);
    final assigned = ref.watch(projectMemberIdsProvider(_project.id));
    final p = _project;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [IconButton(icon: const Icon(Icons.edit), onPressed: _edit)],
      ),
      body: ListView(children: [
        ListTile(title: const Text('Client'), subtitle: Text(p.client.isEmpty ? '—' : p.client)),
        ListTile(title: const Text('Status'), subtitle: Text(p.status)),
        ListTile(
          title: const Text('Dates'),
          subtitle: Text(p.startDate.isEmpty && p.endDate.isEmpty
              ? '—'
              : '${p.startDate.isEmpty ? '?' : p.startDate} → ${p.endDate.isEmpty ? '?' : p.endDate}'),
        ),
        if (p.notes.isNotEmpty) ListTile(title: const Text('Notes'), subtitle: Text(p.notes)),
        const Divider(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Team members', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        AsyncBody<List<Member>>(
          value: members,
          onRetry: () => ref.invalidate(membersProvider),
          builder: (all) => AsyncBody<List<String>>(
            value: assigned,
            onRetry: () => ref.invalidate(projectMemberIdsProvider(_project.id)),
            builder: (ids) {
              _selected ??= ids.toSet();
              if (all.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.all(16), child: Text('Add members in the Members tab first.'));
              }
              return Column(children: [
                for (final m in all)
                  CheckboxListTile(
                    title: Text(m.name),
                    subtitle: m.role.isEmpty ? null : Text(m.role),
                    value: _selected!.contains(m.id),
                    onChanged: (v) => setState(() =>
                        v == true ? _selected!.add(m.id) : _selected!.remove(m.id)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _saving ? null : _saveMembers,
                    child: Text(_saving ? 'Saving…' : 'Save team'),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
