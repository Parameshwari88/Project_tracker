import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import '../util.dart';
import '../widgets/async_view.dart';
import '../widgets/common.dart';
import 'entries_screen.dart' show monthKey;

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  Future<void> _refresh(WidgetRef ref, String key) async {
    ref.invalidate(projectsProvider);
    ref.invalidate(membersProvider);
    ref.invalidate(entriesProvider(key));
    await Future.wait([
      ref.read(projectsProvider.future),
      ref.read(membersProvider.future),
      ref.read(entriesProvider(key).future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final key = monthKey(now);
    final projects = ref.watch(projectsProvider);
    final members = ref.watch(membersProvider);
    final entries = ref.watch(entriesProvider(key));

    final firstError = [projects, members, entries]
        .where((v) => v.hasError)
        .map((v) => v.error!)
        .firstOrNull;
    if (firstError != null) {
      return AsyncBody<void>(
        value: AsyncError<void>(firstError, StackTrace.empty),
        onRetry: () => _refresh(ref, key),
        builder: (_) => const SizedBox(),
      );
    }
    if (!projects.hasValue || !members.hasValue || !entries.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final pl = projects.value!;
    final ml = members.value!;
    final el = entries.value!;
    final totalHours = el.fold<double>(0, (s, e) => s + hoursBetween(e.start, e.end));
    final active = pl.where((p) => p.status == 'active').length;
    final done = pl.where((p) => p.status == 'done').length;
    final pName = {for (final p in pl) p.id: p.name};
    final mName = {for (final m in ml) m.id: m.name};

    final byProject = <String, double>{};
    for (final e in el) {
      byProject[e.projectId] = (byProject[e.projectId] ?? 0) + hoursBetween(e.start, e.end);
    }
    final ranked = byProject.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxH = ranked.isEmpty ? 1.0 : ranked.first.value;
    final recent = [...el]
      ..sort((a, b) => '${b.date} ${b.start}'.compareTo('${a.date} ${a.start}'));

    final name = ref.watch(currentUserProvider)?.name.split(' ').first ?? '';
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    final stats = <_Stat>[
      _Stat('Total projects', '${pl.length}', Icons.folder_copy_rounded, const Color(0xFF4F46E5)),
      _Stat('Active', '$active', Icons.play_circle_rounded, const Color(0xFF0EA5E9)),
      _Stat('Completed', '$done', Icons.check_circle_rounded, const Color(0xFF10B981)),
      _Stat('Members', '${ml.length}', Icons.groups_rounded, const Color(0xFFF59E0B)),
      _Stat('Entries (month)', '${el.length}', Icons.event_note_rounded, const Color(0xFF8B5CF6)),
      _Stat('Hours (month)', totalHours.toStringAsFixed(1), Icons.schedule_rounded, const Color(0xFFEC4899)),
    ];

    return RefreshIndicator(
      onRefresh: () => _refresh(ref, key),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsiveBody(
            maxWidth: 900,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GradientHeader(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.isEmpty ? greeting : '$greeting, $name',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(DateFormat('EEEE, d MMMM yyyy').format(now),
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 18),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(totalHours.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              height: 1,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('hours logged in ${DateFormat('MMMM').format(now)}',
                            style: const TextStyle(color: Colors.white70)),
                      ),
                    ]),
                  ]),
                ),
                const SectionTitle('Overview'),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 640 ? 3 : 2;
                  const gap = 12.0;
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [for (final s in stats) SizedBox(width: w, child: _StatCard(s))],
                  );
                }),
                SectionTitle('Hours by project'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ranked.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('No hours logged this month yet.'),
                          )
                        : Column(children: [
                            for (final r in ranked.take(6))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                child: Column(children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(pName[r.key] ?? '(deleted project)',
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    Text('${r.value.toStringAsFixed(1)} h',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ]),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: r.value / maxH,
                                      minHeight: 8,
                                      color: colorFor(pName[r.key] ?? r.key),
                                      backgroundColor:
                                          colorFor(pName[r.key] ?? r.key).withValues(alpha: 0.12),
                                    ),
                                  ),
                                ]),
                              ),
                          ]),
                  ),
                ),
                const SectionTitle('Recent entries'),
                if (recent.isEmpty)
                  const Card(
                      child: Padding(
                          padding: EdgeInsets.all(20), child: Text('No entries this month yet.')))
                else
                  Card(
                    child: Column(children: [
                      for (var i = 0; i < recent.take(5).length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: InitialAvatar(mName[recent[i].memberId] ?? '?', size: 40),
                          title: Text(mName[recent[i].memberId] ?? '(deleted member)'),
                          subtitle: Text(
                              '${pName[recent[i].projectId] ?? '(deleted project)'} · ${recent[i].date}'),
                          trailing: Text(
                            '${hoursBetween(recent[i].start, recent[i].end).toStringAsFixed(1)} h',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ]),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.s);
  final _Stat s;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(s.icon, color: s.color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(s.value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(s.label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}
