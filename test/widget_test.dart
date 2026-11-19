import 'package:flutter_test/flutter_test.dart';
import 'package:project_tracker/accounts.dart';
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

  group('accounts', () {
    test('first user keeps the original tabs, others get their own prefix', () {
      final a = createUser(name: 'A', phone: '9876543210', password: 'secret1', isFirst: true);
      final b = createUser(name: 'B', phone: '9123456780', password: 'secret2', isFirst: false);
      expect(a.prefix, '');
      expect(b.prefix, startsWith('u'));
      expect(b.prefix, endsWith('_'));
    });
    test('login needs the right mobile number and password', () {
      final u = createUser(name: 'A', phone: '+91 98765-43210', password: 'secret1', isFirst: true);
      expect(findLogin([u], '9876543210', 'secret1'), isNotNull);
      expect(findLogin([u], '9876543210', 'wrong'), isNull);
      expect(findLogin([u], '9999999999', 'secret1'), isNull);
    });
    test('cleared password cells mean a reset is pending', () {
      final u = createUser(name: 'A', phone: '9876543210', password: 'secret1', isFirst: true);
      expect(u.needsReset, isFalse);
      final cleared = AppUser.fromRow([u.id, u.name, u.phone, '', '', u.prefix, '']);
      expect(cleared.needsReset, isTrue);
      expect(findLogin([cleared], '9876543210', ''), isNull);
      expect(passwordMatches(withNewPassword(cleared, 'newpass1'), 'newpass1'), isTrue);
    });
    test('password is not stored in plain text and can be changed', () {
      final u = createUser(name: 'A', phone: '9876543210', password: 'secret1', isFirst: true);
      expect(u.hash.contains('secret1'), isFalse);
      final u2 = withNewPassword(u, 'newpass1');
      expect(passwordMatches(u2, 'newpass1'), isTrue);
      expect(passwordMatches(u2, 'secret1'), isFalse);
    });
  });

  test('friendlyError recognises no internet', () {
    expect(friendlyError(Exception('SocketException: Failed host lookup')), contains('No internet'));
  });
}
