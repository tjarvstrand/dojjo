import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/prompt.dart' as prompt;

class PruneCommand extends Command<void> {
  PruneCommand() {
    argParser.addFlag('yes', abbr: 'y', defaultsTo: false);
  }

  @override
  String get name => 'prune';

  @override
  String get description => 'Remove workspaces whose bookmarks have been merged into trunk';

  @override
  Future<void> run() async {
    final yes = argResults!.flag('yes');
    final workspaces = await jj.workspaceListRich();

    final pruneable = <jj.WorkspaceInfo>[];

    for (final workspace in workspaces) {
      if (workspace.current) continue;
      if (workspace.bookmarks.isEmpty) continue;

      final bookmark = workspace.bookmarks.split(',').first;
      final merged = await jj.revsetMatches('$bookmark & ancestors(trunk())');
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
      stderr.writeln('  ${workspace.name} [${workspace.bookmarks}]');
    }

    await prompt.confirmOrAbort('Remove ${pruneable.length} workspace(s)?', yes: yes);

    for (final workspace in pruneable) {
      final root = await jj.workspaceRoot(workspace.name);
      await jj.workspaceForget(workspace.name);
      try {
        await jj.bookmarkDelete(workspace.bookmarks.split(',').first);
      } on jj.CommandError {
        // Bookmark may not exist.
      }
      await jj.deleteDirectory(root);
      stderr.writeln('  Removed ${workspace.name}');
    }
  }
}
