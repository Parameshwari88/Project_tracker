import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() => runApp(const ProviderScope(child: TrackerApp()));

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Project Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B8A4B)),
          useMaterial3: true,
        ),
        home: const _Gate(),
      );
}

/// Tries silent sign-in, then shows login or home.
class _Gate extends ConsumerStatefulWidget {
  const _Gate();
  @override
  ConsumerState<_Gate> createState() => _GateState();
}

class _GateState extends ConsumerState<_Gate> {
  late Future<bool> _restore;

  @override
  void initState() {
    super.initState();
    _restore = ref
        .read(authProvider)
        .tryRestore()
        .then((a) => a != null)
        .catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _restore,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.data!
              ? HomeScreen(onSignedOut: () => setState(() => _restore = Future.value(false)))
              : LoginScreen(onSignedIn: () => setState(() => _restore = Future.value(true)));
        },
      );
}
