import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/prompt.dart';

class PruneCommand extends Command<void> {
  PruneCommand() {
    argParser.addFlag('yes', abbr: 'y', defaultsTo: false, help: 'Skip confirmation prompts');
  }

  @override
  String get name => 'prune';

  @override
  String get description => 'Remove workspaces whose bookmarks have been merged into trunk';

  @override
  Future<void> run() async {
    final yes = argResults!.flag('yes');
    final workspaces = await workspaceListRich();

    final pruneable = <WorkspaceInfo>[];

    for (final workspace in workspaces) {
      if (workspace.current) continue;
      if (workspace.bookmarks.isEmpty) continue;

      final bookmark = workspace.bookmarks.first;
      final merged = await revsetMatches('$bookmark & ancestors(trunk())');
      if (merged) {
        pruneable.add(workspace);
      }
    }

    if (pruneable.isEmpty) {
      stderr.writeln('No merged workspaces to prune.');
      return;
    }

    stderr.writeln('Workspaces merged into trunk:');
    for (final workspace in pruneable) {
      stderr.writeln('  ${workspace.name} [${workspace.bookmarks.join(',')}]');
    }

    await confirmOrAbort('Remove ${pruneable.length} workspace(s)?', yes: yes);

    for (final workspace in pruneable) {
      final root = await workspaceRoot(workspace.name);
      await workspaceForget(workspace.name);
      try {
        await bookmarkDelete(workspace.bookmarks.first);
      } on CommandError {
        // Bookmark may not exist.
      }
      await deleteDirectory(root);
      stderr.writeln('  Removed ${workspace.name}');
    }
  }
}
