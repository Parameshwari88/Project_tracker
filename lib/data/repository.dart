import '../models.dart';

/// All screens talk to this interface only. The Google Sheets version is used
/// now; a REST API version can replace it when a server is available.
abstract class TrackerRepository {
  Future<List<Project>> projects();
  Future<void> saveProject(Project p);
  Future<void> deleteProject(String id);

  Future<List<Member>> members();
  Future<void> saveMember(Member m);
  Future<void> deleteMember(String id);

  Future<List<String>> memberIdsOf(String projectId);
  Future<void> setProjectMembers(String projectId, List<String> memberIds);

  Future<List<WorkEntry>> entries({String? month}); // month = yyyy-MM
  Future<void> saveEntry(WorkEntry e);
  Future<void> deleteEntry(String id);
}
