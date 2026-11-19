import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'dashboard_screen.dart';
import 'entries_screen.dart';
import 'members_screen.dart';
import 'profile_screen.dart';
import 'projects_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onSignedOut});
  final VoidCallback onSignedOut;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _Dest {
  const _Dest(this.label, this.icon, this.selected);
  final String label;
  final IconData icon;
  final IconData selected;
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  static const _dests = [
    _Dest('Home', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _Dest('Projects', Icons.folder_outlined, Icons.folder_rounded),
    _Dest('Members', Icons.groups_outlined, Icons.groups_rounded),
    _Dest('Entries', Icons.schedule_outlined, Icons.schedule_rounded),
    _Dest('Reports', Icons.insert_chart_outlined, Icons.insert_chart_rounded),
  ];

  void _openProfile() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(onDisconnect: widget.onSignedOut)),
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final initial = (user?.name ?? '?').trim();

    final body = IndexedStack(
      index: _index,
      children: const [
        DashboardTab(),
        ProjectsTab(),
        MembersTab(),
        EntriesTab(),
        ReportsTab(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Dashboard' : _dests[_index].label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openProfile,
              child: CircleAvatar(
                radius: 18,
                child: Text(initial.isEmpty ? '?' : initial[0].toUpperCase()),
              ),
            ),
          ),
        ],
      ),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.transparent,
                destinations: [
                  for (final d in _dests)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: Text(d.label),
                    ),
                ],
              ),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in _dests)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}
