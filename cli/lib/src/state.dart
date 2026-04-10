import 'dart:io';

import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:path/path.dart' as p;

/// The .jj dir of the default workspace — shared across all workspaces.
Future<String> _jjDir() async => p.join(await workspaceRoot('default'), '.jj');

Future<File> _jjStateFile() async => File(p.join(await _jjDir(), 'djo-state'));

/// The djo logs directory, shared across all workspaces.
Future<String> logsDir() async => p.join(await _jjDir(), 'djo', 'logs');

/// Load the previous workspace name.
Future<String?> loadPreviousWorkspace() async {
  try {
    final file = await _jjStateFile();
    if (file.existsSync()) {
      return file.readAsStringSync().trim().nonEmptyOrNull;
    }
  } on Exception {
    // Best-effort.
  }
  return null;
}

/// Save the current workspace name as the previous workspace.
Future<void> savePreviousWorkspace(String name) async {
  try {
    (await _jjStateFile()).writeAsStringSync('$name\n');
  } on Exception {
    // Best-effort.
  }
}
