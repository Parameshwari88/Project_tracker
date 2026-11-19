class Project {
  final String id;
  final String name;
  final String client;
  final String status; // active | done | hold
  final String startDate; // yyyy-MM-dd or ''
  final String endDate;
  final String notes;

  const Project({
    required this.id,
    required this.name,
    this.client = '',
    this.status = 'active',
    this.startDate = '',
    this.endDate = '',
    this.notes = '',
  });

  Project copyWith({
    String? name,
    String? client,
    String? status,
    String? startDate,
    String? endDate,
    String? notes,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        client: client ?? this.client,
        status: status ?? this.status,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        notes: notes ?? this.notes,
      );

  List<String> toRow() => [id, name, client, status, startDate, endDate, notes, ''];

  factory Project.fromRow(List<String> r) => Project(
        id: r[0],
        name: r[1],
        client: r[2],
        status: r[3].isEmpty ? 'active' : r[3],
        startDate: r[4],
        endDate: r[5],
        notes: r[6],
      );
}

class Member {
  final String id;
  final String name;
  final String phone;
  final String role;

  const Member({required this.id, required this.name, this.phone = '', this.role = ''});

  Member copyWith({String? name, String? phone, String? role}) => Member(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        role: role ?? this.role,
      );

  List<String> toRow() => [id, name, phone, role, ''];

  factory Member.fromRow(List<String> r) =>
      Member(id: r[0], name: r[1], phone: r[2], role: r[3]);
}

class WorkEntry {
  final String id;
  final String projectId;
  final String memberId;
  final String date; // yyyy-MM-dd
  final String start; // HH:mm
  final String end; // HH:mm
  final String notes;

  const WorkEntry({
    required this.id,
    required this.projectId,
    required this.memberId,
    required this.date,
    required this.start,
    required this.end,
    this.notes = '',
  });

  List<String> toRow() => [id, projectId, memberId, date, start, end, notes, ''];

  factory WorkEntry.fromRow(List<String> r) => WorkEntry(
        id: r[0],
        projectId: r[1],
        memberId: r[2],
        date: r[3],
        start: r[4],
        end: r[5],
        notes: r[6],
      );
}
