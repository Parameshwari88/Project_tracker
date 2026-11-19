import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/google_auth.dart';
import 'data/repository.dart';
import 'data/sheets_repository.dart';
import 'models.dart';

final authProvider = Provider<GoogleAuthService>((_) => GoogleAuthService());

/// The person logged in to the app (separate from the Google account that owns the Drive).
final currentUserProvider = StateProvider<AppUser?>((_) => null);

/// Each user reads and writes their own tabs. Swap this for an API-backed
/// repository when a server exists.
final repoProvider = Provider<TrackerRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  return SheetsRepository(ref.watch(authProvider), prefix: user?.prefix ?? '');
});

final projectsProvider = FutureProvider<List<Project>>(
  (ref) => ref.watch(repoProvider).projects(),
);

final membersProvider = FutureProvider<List<Member>>(
  (ref) => ref.watch(repoProvider).members(),
);

final projectMemberIdsProvider = FutureProvider.family<List<String>, String>(
  (ref, projectId) => ref.watch(repoProvider).memberIdsOf(projectId),
);

/// Entries for a month (yyyy-MM).
final entriesProvider = FutureProvider.family<List<WorkEntry>, String>(
  (ref, month) => ref.watch(repoProvider).entries(month: month),
);
