import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:uuid/uuid.dart';

import '../models.dart';
import 'google_auth.dart';
import 'repository.dart';

const _dbName = 'Project Tracker DB';

/// Table name -> header row. Last column is always the soft-delete flag.
const _tables = <String, List<String>>{
  'projects': ['id', 'name', 'client', 'status', 'start_date', 'end_date', 'notes', 'deleted'],
  'members': ['id', 'name', 'phone', 'role', 'deleted'],
  'project_members': ['project_id', 'member_id', 'deleted'],
  'work_entries': ['id', 'project_id', 'member_id', 'date', 'start', 'end', 'notes', 'deleted'],
};

class SheetsRepository implements TrackerRepository {
  SheetsRepository(this._auth);

  final GoogleAuthService _auth;
  final _uuid = const Uuid();
  sheets.SheetsApi? _api;
  String? _sheetId;

  Future<sheets.SheetsApi> _sheets() async {
    if (_api != null && _sheetId != null) return _api!;
    final client = await _auth.client();
    final driveApi = drive.DriveApi(client);
    final api = sheets.SheetsApi(client);

    final found = await driveApi.files.list(
      q: "name='$_dbName' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
      $fields: 'files(id)',
      pageSize: 1,
    );
    if (found.files != null && found.files!.isNotEmpty) {
      _sheetId = found.files!.first.id;
    } else {
      final created = await api.spreadsheets.create(sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: _dbName),
        sheets: [
          for (final t in _tables.keys)
            sheets.Sheet(properties: sheets.SheetProperties(title: t)),
        ],
      ));
      _sheetId = created.spreadsheetId;
      for (final e in _tables.entries) {
        await api.spreadsheets.values.update(
          sheets.ValueRange(values: [e.value]),
          _sheetId!,
          '${e.key}!A1',
          valueInputOption: 'RAW',
        );
      }
    }
    _api = api;
    return api;
  }

  /// Returns non-deleted rows with their 1-based sheet row number.
  Future<List<(int, List<String>)>> _read(String table) async {
    final api = await _sheets();
    final cols = _tables[table]!.length;
    final res = await api.spreadsheets.values.get(_sheetId!, '$table!A2:${_col(cols)}');
    final out = <(int, List<String>)>[];
    final rows = res.values ?? const [];
    for (var i = 0; i < rows.length; i++) {
      final r = [for (var c = 0; c < cols; c++) c < rows[i].length ? '${rows[i][c]}' : ''];
      if (r.last.isEmpty) out.add((i + 2, r));
    }
    return out;
  }

  String _col(int n) => String.fromCharCode(64 + n); // 1 -> A (max 26 cols)

  Future<void> _append(String table, List<String> row) async {
    final api = await _sheets();
    await api.spreadsheets.values.append(
      sheets.ValueRange(values: [row]),
      _sheetId!,
      '$table!A1',
      valueInputOption: 'RAW',
      insertDataOption: 'INSERT_ROWS',
    );
  }

  Future<void> _writeRow(String table, int rowNo, List<String> row) async {
    final api = await _sheets();
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: [row]),
      _sheetId!,
      '$table!A$rowNo:${_col(row.length)}$rowNo',
      valueInputOption: 'RAW',
    );
  }

  Future<void> _upsert(String table, String id, List<String> row) async {
    final rows = await _read(table);
    final hit = rows.where((r) => r.$2[0] == id);
    if (hit.isEmpty) {
      await _append(table, row);
    } else {
      await _writeRow(table, hit.first.$1, row);
    }
  }

  Future<void> _softDelete(String table, bool Function(List<String>) match) async {
    for (final r in await _read(table)) {
      if (match(r.$2)) {
        final row = [...r.$2]..[r.$2.length - 1] = '1';
        await _writeRow(table, r.$1, row);
      }
    }
  }

  // --- projects ---
  @override
  Future<List<Project>> projects() async =>
      [for (final r in await _read('projects')) Project.fromRow(r.$2)];

  @override
  Future<void> saveProject(Project p) async {
    final id = p.id.isEmpty ? _uuid.v4() : p.id;
    await _upsert('projects', id, Project(
      id: id, name: p.name, client: p.client, status: p.status,
      startDate: p.startDate, endDate: p.endDate, notes: p.notes,
    ).toRow());
  }

  @override
  Future<void> deleteProject(String id) async {
    await _softDelete('projects', (r) => r[0] == id);
    await _softDelete('project_members', (r) => r[0] == id);
  }

  // --- members ---
  @override
  Future<List<Member>> members() async =>
      [for (final r in await _read('members')) Member.fromRow(r.$2)];

  @override
  Future<void> saveMember(Member m) async {
    final id = m.id.isEmpty ? _uuid.v4() : m.id;
    await _upsert('members', id,
        Member(id: id, name: m.name, phone: m.phone, role: m.role).toRow());
  }

  @override
  Future<void> deleteMember(String id) async {
    await _softDelete('members', (r) => r[0] == id);
    await _softDelete('project_members', (r) => r[1] == id);
  }

  // --- assignments ---
  @override
  Future<List<String>> memberIdsOf(String projectId) async => [
        for (final r in await _read('project_members'))
          if (r.$2[0] == projectId) r.$2[1],
      ];

  @override
  Future<void> setProjectMembers(String projectId, List<String> memberIds) async {
    final current = await memberIdsOf(projectId);
    for (final id in memberIds.where((m) => !current.contains(m))) {
      await _append('project_members', [projectId, id, '']);
    }
    await _softDelete('project_members',
        (r) => r[0] == projectId && !memberIds.contains(r[1]));
  }

  // --- work entries ---
  @override
  Future<List<WorkEntry>> entries({String? month}) async => [
        for (final r in await _read('work_entries'))
          if (month == null || r.$2[3].startsWith(month)) WorkEntry.fromRow(r.$2),
      ];

  @override
  Future<void> saveEntry(WorkEntry e) async {
    final id = e.id.isEmpty ? _uuid.v4() : e.id;
    await _upsert('work_entries', id, WorkEntry(
      id: id, projectId: e.projectId, memberId: e.memberId, date: e.date,
      start: e.start, end: e.end, notes: e.notes,
    ).toRow());
  }

  @override
  Future<void> deleteEntry(String id) =>
      _softDelete('work_entries', (r) => r[0] == id);
}
