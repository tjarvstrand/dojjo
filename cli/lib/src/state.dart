import 'dart:io';

import 'package:dojjo/src/jj.dart' as jj;
import 'package:path/path.dart' as p;

Future<String> _stateFilePath() async {
  final root = await jj.workspaceRoot();
  return p.join(root, '.jj', 'djo-state');
}

Future<String?> loadPreviousWorkspace() async {
  try {
    final path = await _stateFilePath();
    final file = File(path);
    if (await file.exists()) {
      final content = (await file.readAsString()).trim();
      return content.isNotEmpty ? content : null;
    }
  } on Exception {
    // State file is best-effort.
  }
  return null;
}

Future<void> savePreviousWorkspace(String name) async {
  try {
    final path = await _stateFilePath();
    await File(path).writeAsString('$name\n');
  } on Exception {
    // State file is best-effort.
  }
}
