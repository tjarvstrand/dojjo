import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/jj.dart' as jj;

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
      final output = await jj.gitPush(all: true);
      if (output.isNotEmpty) {
        stderr.writeln(output);
      }
      return;
    }

    // Push the current workspace's bookmark.
    final workspaces = await jj.workspaceListRich();
    final current = workspaces.where((workspace) => workspace.current).firstOrNull;
    if (current == null || current.bookmarks.isEmpty) {
      stderr.writeln('No bookmark found for current workspace.');
      exit(1);
    }

    // Use the first bookmark if multiple are present.
    final bookmark = current.bookmarks.split(',').first;
    final output = await jj.gitPush(bookmark: bookmark);
    if (output.isNotEmpty) {
      stderr.writeln(output);
    }
  }
}
