import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});
  final VoidCallback onSignedIn;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider).signIn();
      widget.onSignedIn();
    } catch (_) {
      setState(() => _error = 'Sign-in failed. Check your internet and Google setup.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.assignment_turned_in, size: 72),
                const SizedBox(height: 16),
                Text('Project Tracker',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  'Your data is stored in your own Google Drive.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: const Icon(Icons.login),
                  label: Text(_busy ? 'Signing in…' : 'Sign in with Google'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
        ),
      );
}
