import 'dart:io';

import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:path/path.dart' as p;

/// The shared .jj dir for the repo. In a primary workspace, `.jj/repo` is a
/// directory; in secondary workspaces it's a text file pointing to the
/// primary's `.jj/repo`. We resolve back to the parent `.jj` dir either way.
Future<String> _jjDir() async {
  final jjDir = p.join(await workspaceRoot(), '.jj');
  final repoEntry = File(p.join(jjDir, 'repo'));
  if (await repoEntry.exists() && await FileSystemEntity.type(repoEntry.path) == FileSystemEntityType.file) {
    // Secondary workspace — follow the pointer to the primary's .jj dir.
    final repoPath = (await repoEntry.readAsString()).trim();
    return p.dirname(repoPath);
  }
  return jjDir;
}

/// The root of the primary (default) workspace.
Future<String> primaryWorkspaceRoot() async => p.dirname(await _jjDir());

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
