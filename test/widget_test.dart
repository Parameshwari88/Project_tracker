import 'package:flutter_test/flutter_test.dart';
import 'package:project_tracker/models.dart';
import 'package:project_tracker/report/report_service.dart';
import 'package:project_tracker/util.dart';

void main() {
  group('hoursBetween', () {
    test('simple range', () => expect(hoursBetween('09:00', '17:30'), 8.5));
    test('minutes', () => expect(hoursBetween('09:15', '10:00'), 0.75));
    test('same time is zero', () => expect(hoursBetween('09:00', '09:00'), 0));
    test('crossing midnight', () => expect(hoursBetween('22:00', '02:00'), 4));
    test('invalid input is zero', () {
      expect(hoursBetween('', '10:00'), 0);
      expect(hoursBetween('9', 'x:y'), 0);
    });
  });

  group('buildReportBytes', () {
    const p = Project(id: 'p1', name: 'Site A');
    const m = Member(id: 'm1', name: 'Ravi');
    const e = WorkEntry(
        id: 'e1', projectId: 'p1', memberId: 'm1', date: '2026-11-03', start: '09:00', end: '13:30');

    test('returns null when no entries', () {
      expect(buildReportBytes(month: '2026-11', projects: [p], members: [m], entries: []), isNull);
    });

    test('builds a file when there are entries', () {
      final bytes =
          buildReportBytes(month: '2026-11', projects: [p], members: [m], entries: [e]);
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);
    });
  });

  test('friendlyError recognises no internet', () {
    expect(friendlyError(Exception('SocketException: Failed host lookup')), contains('No internet'));
  });
}
