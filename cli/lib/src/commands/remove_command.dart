import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart' as hooks;
import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/prompt.dart' as prompt;

class RemoveCommand extends Command<void> {
  RemoveCommand(this._config) {
    argParser
      ..addFlag('yes', abbr: 'y', defaultsTo: false)
      ..addFlag('keep-bookmark', defaultsTo: false)
      ..addFlag('skip-hooks', defaultsTo: false, help: 'Skip hooks');
  }

  final Config _config;

  @override
  String get name => 'remove';

  @override
  String get description => 'Forget a jj workspace and delete its directory';

  @override
  Future<void> run() async {
    final yes = argResults!.flag('yes');
    final keepBookmark = argResults!.flag('keep-bookmark');
    final skipHooks = argResults!.flag('skip-hooks');
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <name>');
    }
    final name = rest.first;

    final root = await jj.workspaceRoot(name);
    final message = keepBookmark
        ? "Will forget workspace '$name' and delete $root"
        : "Will forget workspace '$name', delete bookmark, and delete $root";
    stderr.writeln(message);
    await prompt.confirmOrAbort('Proceed?', yes: yes);

    if (!skipHooks) {
      await hooks.runHooks(
        'pre-remove',
        hooks: _config.hooks,
        name: name,
        path: root,
      );
    }

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

    if (!skipHooks) {
      await hooks.runHooks(
        'post-remove',
        hooks: _config.hooks,
        name: name,
        path: root,
      );
    }
  }
}
