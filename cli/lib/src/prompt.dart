import 'dart:io';

Future<bool> confirm(String message) async {
  stderr.write('$message [y/N] ');
  final input = stdin.readLineSync() ?? '';
  return input.trim().toLowerCase() == 'y';
}

Future<void> confirmOrAbort(String message, {required bool yes}) async {
  if (yes) return;
  if (!await confirm(message)) {
    throw Exception('Aborted');
  }
}
