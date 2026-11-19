import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _dateFmt = DateFormat('yyyy-MM-dd');

String fmtDate(DateTime d) => _dateFmt.format(d);
DateTime parseDate(String s) => DateTime.tryParse(s) ?? DateTime.now();

String fmtTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay parseTime(String s) {
  final p = s.split(':');
  if (p.length != 2) return const TimeOfDay(hour: 9, minute: 0);
  return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
}

/// Hours between two HH:mm strings. If [end] is earlier than [start] the shift
/// is taken to cross midnight. Invalid input gives 0.
double hoursBetween(String start, String end) {
  int? mins(String s) {
    final p = s.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  final a = mins(start);
  final b = mins(end);
  if (a == null || b == null) return 0;
  var diff = b - a;
  if (diff < 0) diff += 24 * 60;
  return diff / 60.0;
}

bool isNoInternet(Object e) =>
    e is SocketException ||
    e is TimeoutException ||
    e.toString().contains('SocketException') ||
    e.toString().contains('Failed host lookup') ||
    e.toString().contains('ClientException');

String friendlyError(Object e) => isNoInternet(e)
    ? 'No internet connection. This app needs internet to read and save your data. Check your connection and try again.'
    : 'Something went wrong. Please try again.\n\n$e';

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(isNoInternet(e) ? 'No internet connection.' : 'Error: $e'),
    ));
}

Future<bool> confirm(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Are you sure?'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ],
    ),
  );
  return r ?? false;
}
