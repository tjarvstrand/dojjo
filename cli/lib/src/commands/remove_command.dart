import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart';
import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/prompt.dart';

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

    final root = await workspaceRoot(name);
    stderr.writeln("Will forget workspace '$name'${keepBookmark ? '' : ', delete bookmark'}, and delete $root");
    await confirmOrAbort('Proceed?', yes: yes);

    if (!skipHooks) {
      await runHooks('pre-remove', hooks: _config.hooks, name: name, path: root);
    }

    await workspaceForget(name);
    if (!keepBookmark) {
      try {
        await bookmarkDelete(name);
      } on CommandError {
        // ignore: bookmark may not exist
      }
    }
    await deleteDirectory(root);
    stderr.writeln("Removed workspace '$name'");

    if (!skipHooks) {
      await runHooks('post-remove', hooks: _config.hooks, name: name, path: root);
    }
  }
}
