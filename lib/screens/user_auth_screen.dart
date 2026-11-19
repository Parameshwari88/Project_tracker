import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// Login / registration for people using this app. Shown after the Google
/// account (which owns the Drive) is connected.
class UserAuthScreen extends ConsumerStatefulWidget {
  const UserAuthScreen({super.key, required this.onDisconnect});
  final VoidCallback onDisconnect;

  @override
  ConsumerState<UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends ConsumerState<UserAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  List<AppUser>? _users;
  Object? _loadError;
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _users = null;
      _loadError = null;
    });
    try {
      final list = await ref.read(repoProvider).users();
      if (!mounted) return;
      setState(() {
        _users = list;
        _register = list.isEmpty; // first person must register
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// A user whose password was cleared in the sheet and who now sets a new one.
  AppUser? get _resetUser {
    if (_register || _users == null) return null;
    final p = normalisePhone(_phone.text);
    if (p.length < 10) return null;
    for (final u in _users!) {
      if (u.phone == p && u.needsReset) return u;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final resetUser = _resetUser;
    if (resetUser != null) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final updated = withNewPassword(resetUser, _pass.text);
        await ref.read(repoProvider).saveUser(updated);
        ref.read(currentUserProvider.notifier).state = updated;
      } catch (e) {
        if (mounted) showError(context, e);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(repoProvider);
      if (_register) {
        // Re-read so two people registering around the same time do not clash.
        final latest = await repo.users();
        if (latest.any((u) => u.phone == normalisePhone(_phone.text))) {
          setState(() => _error = 'This mobile number is already registered. Please log in.');
          return;
        }
        final user = createUser(
          name: _name.text,
          phone: _phone.text,
          password: _pass.text,
          isFirst: latest.isEmpty,
        );
        await repo.saveUser(user);
        ref.read(currentUserProvider.notifier).state = user;
      } else {
        final user = findLogin(_users!, _phone.text, _pass.text);
        if (user == null) {
          setState(() => _error = 'Wrong mobile number or password.');
          return;
        }
        ref.read(currentUserProvider.notifier).state = user;
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loadError != null) {
      content = Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(isNoInternet(_loadError!) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 44),
            const SizedBox(height: 12),
            Text(friendlyError(_loadError!), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
            TextButton(onPressed: widget.onDisconnect, child: const Text('Use a different Google account')),
          ]),
        ),
      );
    } else if (_users == null) {
      content = const Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else {
      content = _formCard(context);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBrandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ResponsiveBody(
                maxWidth: 440,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration:
                        BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                    child: Icon(_register ? Icons.person_add_alt_1_rounded : Icons.lock_rounded,
                        size: 42, color: kBrand),
                  ),
                  const SizedBox(height: 18),
                  Text(_register ? 'Create your profile' : 'Welcome back',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    _register
                        ? 'Register with your name, mobile number and a password.'
                        : 'Log in with your mobile number and password.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  content,
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    final reset = _resetUser != null;
    final needsConfirm = _register || reset;
    return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_register) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Full name', prefixIcon: Icon(Icons.person_rounded)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(
                    labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                validator: (v) =>
                    normalisePhone(v ?? '').length < 10 ? 'Enter a 10-digit mobile number' : null,
              ),
              if (reset)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                        'Your password was reset. Choose a new password to continue.'),
                  ),
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: reset ? 'New password' : 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v == null || v.length < (needsConfirm ? 6 : 1))
                    ? (needsConfirm ? 'At least 6 characters' : 'Required')
                    : null,
              ),
              if (needsConfirm) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass2,
                  obscureText: _hide,
                  decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.check_circle_outline_rounded)),
                  validator: (v) => v != _pass.text ? 'Passwords do not match' : null,
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy
                    ? 'Please wait…'
                    : (_register ? 'Register' : (reset ? 'Set password and log in' : 'Log in'))),
              ),
              if (_users!.isNotEmpty)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                  child: Text(_register
                      ? 'Already registered? Log in'
                      : 'New user? Register'),
                ),
              TextButton(
                onPressed: _busy ? null : widget.onDisconnect,
                child: const Text('Use a different Google account'),
              ),
            ]),
          ),
        ),
      );
  }
}
