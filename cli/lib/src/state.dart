import 'dart:io';

import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:path/path.dart' as p;

/// The shared .jj dir for the repo that [workspacePath] belongs to. In a
/// primary workspace, `.jj/repo` is a directory; in secondary workspaces it's
/// a text file pointing to the primary's `.jj/repo`. We resolve back to the
/// parent `.jj` dir either way.
///
/// The pointer in that file is relative to the workspace's own `.jj` dir (jj
/// may also write an absolute path there), so it must be resolved against
/// [workspacePath] and never against the current working directory.
String sharedJjDir(String workspacePath) {
  final jjDir = p.join(workspacePath, '.jj');
  final repoEntry = File(p.join(jjDir, 'repo'));
  if (repoEntry.existsSync() && FileSystemEntity.typeSync(repoEntry.path) == FileSystemEntityType.file) {
    final repoPath = repoEntry.readAsStringSync().trim();
    if (repoPath.isEmpty) return jjDir;
    return p.normalize(p.dirname(p.join(jjDir, repoPath)));
  }
  return jjDir;
}

Future<String> _jjDir() async => sharedJjDir(await workspaceRoot());

/// The root of the primary (default) workspace.
Future<String> primaryWorkspaceRoot() async => p.dirname(await _jjDir());

Future<File> _jjStateFile() async => File(p.join(await _jjDir(), 'djo-state'));

/// The djo logs directory, shared across all workspaces.
Future<String> logsDir() async => p.join(await _jjDir(), 'djo', 'logs');

/// Load the previous workspace name, or `null` if none is recorded.
Future<String?> loadPreviousWorkspace() async {
  final file = await _jjStateFile();
  if (!file.existsSync()) return null;
  return file.readAsStringSync().trim().nonEmptyOrNull;
}

/// Save the current workspace name as the previous workspace.
Future<void> savePreviousWorkspace(String name) async {
  (await _jjStateFile()).writeAsStringSync('$name\n');
}

/// Clear the previous-workspace pointer (e.g. when the workspace it pointed to
/// has been removed, so it can never reference a deleted or current workspace).
Future<void> clearPreviousWorkspace() async {
  final file = await _jjStateFile();
  if (file.existsSync()) file.deleteSync();
}

/// Clear the previous-workspace pointer if it references any of [removedNames],
/// so `switch -` never points at a workspace that no longer exists.
///
/// Call this *before* deleting the workspace directory: the state file is
/// resolved relative to the current workspace, which must still exist.
Future<void> clearPreviousWorkspaceIfRemoved(Iterable<String> removedNames) async {
  final previous = await loadPreviousWorkspace();
  if (previous != null && removedNames.contains(previous)) {
    await clearPreviousWorkspace();
  }
}
