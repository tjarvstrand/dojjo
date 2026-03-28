import 'dart:io';

import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:path/path.dart' as p;

Future<String> _jjDir() async {
  final root = await workspaceRoot();
  return p.join(root, '.jj');
}

// --- Previous workspace ---

Future<String?> loadPreviousWorkspace() async {
  try {
    final path = p.join(await _jjDir(), 'djo-state');
    final file = File(path);
    if (await file.exists()) {
      final content = (await file.readAsString()).trim();
      return content.nonEmptyOrNull;
    }
  } on Exception {
    // Best-effort.
  }
  return null;
}

Future<void> savePreviousWorkspace(String name) async {
  try {
    final path = p.join(await _jjDir(), 'djo-state');
    await File(path).writeAsString('$name\n');
  } on Exception {
    // Best-effort.
  }
}
