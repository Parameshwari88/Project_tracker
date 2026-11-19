import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts.dart';
import '../models.dart';
import '../providers.dart';
import '../util.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.onDisconnect});

  /// Signs out of Google (and the app user).
  final VoidCallback onDisconnect;

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    ref.read(currentUserProvider.notifier).state = null;
  }

  Future<void> _disconnect(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Disconnect Google account?'),
        content: const Text(
            'You will be logged out and the Google account will be signed out of this app. Your data stays in the Drive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.pop(context);
    onDisconnect();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final google = ref.read(authProvider).account;
    final name = user?.name ?? 'User';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ResponsiveBody(
        maxWidth: 600,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          GradientHeader(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white,
                child: Text(name.isEmpty ? '?' : name.trim()[0].toUpperCase(),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 14),
              Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              if (user != null)
                Text('+91 ${user.phone}', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          const SectionTitle('Profile'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('Name'),
                subtitle: Text(name),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.phone_iphone_rounded),
                title: const Text('Mobile number'),
                subtitle: Text(user == null ? '—' : '+91 ${user.phone}'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: user == null
                    ? null
                    : () async {
                        final changed = await showDialog<bool>(
                          context: context,
                          builder: (_) => _ChangePasswordDialog(user: user),
                        );
                        if (changed == true && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Password changed')));
                        }
                      },
              ),
            ]),
          ),
          const SectionTitle('Storage'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_done_rounded),
              title: const Text('Google Drive'),
              subtitle: Text(google?.email ?? '"Project Tracker DB" sheet'),
            ),
          ),
          const SectionTitle('About'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Project Tracker'),
              subtitle: Text('Version 1.0.0'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
            ),
            onPressed: () => _disconnect(context),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Disconnect Google account'),
          ),
        ]),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({required this.user});
  final AppUser user;

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _new2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!passwordMatches(widget.user, _old.text)) {
      setState(() => _error = 'Current password is wrong.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = withNewPassword(widget.user, _new.text);
      await ref.read(repoProvider).saveUser(updated);
      ref.read(currentUserProvider.notifier).state = updated;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _old,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'New password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new2,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.check_circle_outline_rounded)),
                validator: (v) => v != _new.text ? 'Passwords do not match' : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      );
}
