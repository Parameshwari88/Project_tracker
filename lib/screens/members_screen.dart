import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';
import '../util.dart';
import '../widgets/async_view.dart';

class MembersTab extends ConsumerWidget {
  const MembersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(membersProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add member',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MemberFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: AsyncBody<List<Member>>(
        value: value,
        onRetry: () => ref.invalidate(membersProvider),
        builder: (list) => list.isEmpty
            ? const EmptyState('No members yet. Tap + to add one.')
            : RefreshIndicator(
                onRefresh: () => ref.refresh(membersProvider.future),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = list[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())),
                      title: Text(m.name),
                      subtitle: Text([m.role, m.phone].where((s) => s.isNotEmpty).join(' · ')),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => MemberFormScreen(member: m))),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, this.member});
  final Member? member;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.member?.name);
  late final _phone = TextEditingController(text: widget.member?.phone);
  late final _role = TextEditingController(text: widget.member?.role);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final base = widget.member ?? Member(id: const Uuid().v4(), name: '');
      await ref.read(repoProvider).saveMember(base.copyWith(
          name: _name.text.trim(), phone: _phone.text.trim(), role: _role.text.trim()));
      ref.invalidate(membersProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this member? Their past entries stay in the records.')) return;
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).deleteMember(widget.member!.id);
      ref.invalidate(membersProvider);
      if (mounted) Navigator.pop(context);
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
          title: Text(widget.member == null ? 'New member' : 'Edit member'),
          actions: [
            if (widget.member != null)
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
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(controller: _role, decoration: const InputDecoration(labelText: 'Role')),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ]),
        ),
      );
}
