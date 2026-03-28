import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/util/extensions.dart';

class PushCommand extends Command<void> {
  PushCommand() {
    argParser.addFlag('all', defaultsTo: false, help: 'Push all tracked bookmarks');
  }

  @override
  String get name => 'push';

  @override
  String get description => 'Push bookmarks to remote';

  @override
  Future<void> run() async {
    final all = argResults!.flag('all');

    if (all) {
      (await gitPush(all: true))?.let(stderr.writeln);
      return;
    }

    // Push the current workspace's bookmark.
    final workspaces = await workspaceListRich();
    final current = workspaces.where((workspace) => workspace.current).firstOrNull;
    if (current == null || current.bookmarks.isEmpty) {
      throw Exception('No bookmark found for current workspace.');
    }

    // Use the first bookmark if multiple are present.
    final bookmark = current.bookmarks.split(',').first;
    (await gitPush(bookmark: bookmark))?.let(stderr.writeln);
  }
}
