import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../util.dart';

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Builds the monthly .xlsx. One sheet per project with entries, plus Summary.
/// [month] is yyyy-MM. Returns null when there are no entries to report.
List<int>? buildReportBytes({
  required String month,
  required List<Project> projects,
  required List<Member> members,
  required List<WorkEntry> entries,
}) {
  if (entries.isEmpty) return null;
  final memberName = {for (final m in members) m.id: m.name};
  final excel = Excel.createExcel();
  final summary = excel['Summary'];
  final usedNames = <String>{'Summary'};
  final summaryRows = <(String, double)>[];

  for (final p in projects) {
    final list = entries.where((e) => e.projectId == p.id).toList()
      ..sort((a, b) => '${a.date} ${a.start}'.compareTo('${b.date} ${b.start}'));
    if (list.isEmpty) continue;

    var name = p.name.replaceAll(RegExp(r'[\/*?:\[\]]'), '_');
    if (name.isEmpty) name = 'Project';
    if (name.length > 28) name = name.substring(0, 28);
    var unique = name;
    var n = 2;
    while (usedNames.contains(unique.toLowerCase()) || usedNames.contains(unique)) {
      unique = '$name ($n)';
      n++;
    }
    usedNames.add(unique);

    final sheet = excel[unique];
    sheet.appendRow(
        [TextCellValue('Date'), TextCellValue('Member'), TextCellValue('In'), TextCellValue('Out'), TextCellValue('Hours')]);
    var total = 0.0;
    for (final e in list) {
      final h = _round2(hoursBetween(e.start, e.end));
      total += h;
      sheet.appendRow([
        TextCellValue(e.date),
        TextCellValue(memberName[e.memberId] ?? '(deleted member)'),
        TextCellValue(e.start),
        TextCellValue(e.end),
        DoubleCellValue(h),
      ]);
    }
    sheet.appendRow([
      TextCellValue('Total'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(_round2(total)),
    ]);
    summaryRows.add((p.name, _round2(total)));
  }

  summary.appendRow([TextCellValue('Project'), TextCellValue('Total hours')]);
  var grand = 0.0;
  for (final r in summaryRows) {
    summary.appendRow([TextCellValue(r.$1), DoubleCellValue(r.$2)]);
    grand += r.$2;
  }
  summary.appendRow([TextCellValue('Total'), DoubleCellValue(_round2(grand))]);

  // Per-member totals.
  summary.appendRow([TextCellValue('')]);
  summary.appendRow([TextCellValue('Member'), TextCellValue('Total hours')]);
  final byMember = <String, double>{};
  for (final e in entries) {
    final nm = memberName[e.memberId] ?? '(deleted member)';
    byMember[nm] = (byMember[nm] ?? 0) + hoursBetween(e.start, e.end);
  }
  for (final kv in byMember.entries) {
    summary.appendRow([TextCellValue(kv.key), DoubleCellValue(_round2(kv.value))]);
  }

  excel.setDefaultSheet('Summary');
  if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
  return excel.save();
}

/// Writes the report to the temp directory and opens the share sheet. The file
/// is deleted again afterwards; nothing is kept permanently.
Future<void> shareReport(List<int> bytes, String month) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/work-report-$month.xlsx');
  await file.writeAsBytes(bytes, flush: true);
  try {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile(file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      ],
      subject: 'Work report $month',
    ));
  } finally {
    if (await file.exists()) await file.delete();
  }
}

