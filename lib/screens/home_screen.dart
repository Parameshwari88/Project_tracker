import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../util.dart';
import 'entries_screen.dart';
import 'members_screen.dart';
import 'projects_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onSignedOut});
  final VoidCallback onSignedOut;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;
  static const _titles = ['Projects', 'Members', 'Entries', 'Reports'];

  Future<void> _signOut() async {
    try {
      await ref.read(authProvider).signOut();
      widget.onSignedOut();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authProvider).account?.email;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: email == null ? 'Sign out' : 'Sign out ($email)',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [ProjectsTab(), MembersTab(), EntriesTab(), ReportsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Entries'),
          NavigationDestination(icon: Icon(Icons.table_chart_outlined), selectedIcon: Icon(Icons.table_chart), label: 'Reports'),
        ],
      ),
    );
  }
}
