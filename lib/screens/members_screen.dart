import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../providers.dart';
import '../util.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';

class MembersTab extends ConsumerWidget {
  const MembersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(membersProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MemberFormScreen())),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New member'),
      ),
      body: AsyncBody<List<Member>>(
        value: value,
        onRetry: () => ref.invalidate(membersProvider),
        builder: (list) => list.isEmpty
            ? const EmptyState('No members yet. Tap + to add one.')
            : RefreshIndicator(
                onRefresh: () => ref.refresh(membersProvider.future),
                child: ResponsiveBody(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final sub = [m.role, m.phone].where((s) => s.isNotEmpty).join(' · ');
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: InitialAvatar(m.name),
                          title: Text(m.name,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: sub.isEmpty ? null : Text(sub),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MemberFormScreen(member: m))),
                        ),
                      );
                    },
                  ),
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
        body: ResponsiveBody(
          maxWidth: 600,
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Full name *', prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                    labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                  controller: _role,
                  decoration: const InputDecoration(
                      labelText: 'Role', prefixIcon: Icon(Icons.badge_rounded))),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save member'),
              ),
            ]),
          ),
        ),
      );
}
