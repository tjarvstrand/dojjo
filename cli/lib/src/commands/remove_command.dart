import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/prompt.dart' as prompt;

class RemoveCommand extends Command<void> {
  RemoveCommand() {
    argParser
      ..addFlag('yes', abbr: 'y', defaultsTo: false)
      ..addFlag('keep-bookmark', defaultsTo: false);
  }

  @override
  String get name => 'remove';

  @override
  String get description => 'Forget a jj workspace and delete its directory';

  @override
  Future<void> run() async {
    final yes = argResults!.flag('yes');
    final keepBookmark = argResults!.flag('keep-bookmark');
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <name>');
    }
    final name = rest.first;

    final root = await jj.workspaceRoot(name);
    final msg = keepBookmark
        ? "Will forget workspace '$name' and delete $root"
        : "Will forget workspace '$name', delete bookmark, and delete $root";
    stderr.writeln(msg);
    await prompt.confirmOrAbort('Proceed?', yes: yes);

    await jj.workspaceForget(name);
    if (!keepBookmark) {
      try {
        await jj.bookmarkDelete(name);
      } on jj.CommandError {
        // ignore: bookmark may not exist
      }
    }
    await jj.deleteDirectory(root);
    stderr.writeln("Removed workspace '$name'");
  }
}
