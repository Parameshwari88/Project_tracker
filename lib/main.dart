import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/user_auth_screen.dart';
import 'theme.dart';

void main() => runApp(const ProviderScope(child: TrackerApp()));

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Project Tracker',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const _Gate(),
      );
}

/// Splash -> Google sign-in (connects the Drive) -> home.
class _Gate extends ConsumerStatefulWidget {
  const _Gate();
  @override
  ConsumerState<_Gate> createState() => _GateState();
}

enum _Stage { checking, signedOut, signedIn }

class _GateState extends ConsumerState<_Gate> {
  _Stage _stage = _Stage.checking;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    // Keep the splash animation on screen for at least 2 seconds.
    final minSplash = Future.delayed(const Duration(milliseconds: 2000));
    bool ok;
    try {
      ok = await ref.read(authProvider).tryRestore() != null;
    } catch (_) {
      ok = false;
    }
    await minSplash;
    if (!mounted) return;
    setState(() => _stage = ok ? _Stage.signedIn : _Stage.signedOut);
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.checking:
        return const SplashScreen();
      case _Stage.signedOut:
        return LoginScreen(onSignedIn: () => setState(() => _stage = _Stage.signedIn));
      case _Stage.signedIn:
        final user = ref.watch(currentUserProvider);
        if (user == null) return UserAuthScreen(onDisconnect: _disconnectGoogle);
        return HomeScreen(onSignedOut: _disconnectGoogle);
    }
  }

  /// Signs out of the Google account and logs out the app user too.
  Future<void> _disconnectGoogle() async {
    try {
      await ref.read(authProvider).signOut();
    } catch (_) {}
    if (!mounted) return;
    ref.read(currentUserProvider.notifier).state = null;
    setState(() => _stage = _Stage.signedOut);
  }
}
