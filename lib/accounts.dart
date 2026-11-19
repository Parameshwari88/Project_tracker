import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

/// Keeps the last 10 digits, so "+91 98765-43210" and "9876543210" match.
String normalisePhone(String s) {
  final d = s.replaceAll(RegExp(r'\D'), '');
  return d.length > 10 ? d.substring(d.length - 10) : d;
}

String _hash(String salt, String phone, String password) {
  List<int> bytes = utf8.encode('$salt|$phone|$password');
  for (var i = 0; i < 20000; i++) {
    bytes = sha256.convert(bytes).bytes;
  }
  return base64Url.encode(bytes);
}

String _newSalt() {
  final rnd = Random.secure();
  return base64Url.encode([for (var i = 0; i < 16; i++) rnd.nextInt(256)]);
}

/// Creates a user. The first user ([isFirst]) keeps the original tabs
/// (prefix ''); everyone else gets their own tab prefix.
AppUser createUser({
  required String name,
  required String phone,
  required String password,
  required bool isFirst,
}) {
  final salt = _newSalt();
  final p = normalisePhone(phone);
  final id = const Uuid().v4();
  return AppUser(
    id: id,
    name: name.trim(),
    phone: p,
    salt: salt,
    hash: _hash(salt, p, password),
    prefix: isFirst ? '' : 'u${id.substring(0, 6)}_',
  );
}

bool passwordMatches(AppUser u, String password) =>
    _hash(u.salt, u.phone, password) == u.hash;

/// Returns the user with this mobile number and password, or null.
AppUser? findLogin(List<AppUser> users, String phone, String password) {
  final p = normalisePhone(phone);
  for (final u in users) {
    if (u.phone == p && passwordMatches(u, password)) return u;
  }
  return null;
}

AppUser withNewPassword(AppUser u, String newPassword) {
  final salt = _newSalt();
  return u.copyWith(salt: salt, hash: _hash(salt, u.phone, newPassword));
}
