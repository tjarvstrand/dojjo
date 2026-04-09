import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart';
import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/prompt.dart';
import 'package:dojjo/src/state.dart';
import 'package:dojjo/src/util/extensions.dart';

class RemoveCommand extends Command<void> {
  RemoveCommand(this._config) {
    argParser
      ..addFlag('yes', abbr: 'y', defaultsTo: false, help: 'Skip confirmation prompts')
      ..addFlag('keep-bookmark', defaultsTo: false, help: 'Do not delete the bookmark (implies --keep-revision)')
      ..addFlag('keep-revision', defaultsTo: false, help: 'Do not abandon the revision')
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
    final keepRevision = argResults!.flag('keep-revision');
    final skipHooks = argResults!.flag('skip-hooks');
    final rest = argResults!.rest;

    final workspaces = await workspaceListRich();
    final current = workspaces.where((workspace) => workspace.current).firstOrNull;

    final name = rest.isEmpty ? current?.name : rest.first;
    if (name == null) {
      usageException('Missing required argument: <name>');
    }

    final workspace = workspaces.where((workspace) => workspace.name == name).firstOrNull;
    final removingCurrent = name == current?.name;
    final root = await workspaceRoot(name);
    stderr.writeln("Will forget workspace '$name'${keepBookmark ? '' : ', delete bookmark'}, and delete $root");
    await confirmOrAbort('Proceed?', yes: yes);

    if (!skipHooks) {
      await runHooks('pre-remove', hooks: _config.hooks, name: name, path: root);
    }

    // Resolve paths that we'll need after deletion, while the cwd still exists.
    final changeId = workspace?.changeId;
    final otherBookmarks = workspace?.bookmarks.where((bookmark) => bookmark != name).toList() ?? [];
    final defaultRoot = removingCurrent || !skipHooks ? await workspaceRoot('default') : null;
    final previous = removingCurrent ? await loadPreviousWorkspace() : null;
    final previousRoot = await previous?.let(workspaceRoot) ?? (removingCurrent ? defaultRoot : null);

    await workspaceForget(name);
    if (!keepBookmark) {
      await bookmarkDelete(name).ignoreErrors<CommandError>();
    }

    // Abandon the revision if no other bookmarks point to it.
    if (!keepRevision && !keepBookmark && otherBookmarks.isEmpty && changeId != null) {
      await abandon(changeId).ignoreErrors<CommandError>();
    }

    await deleteDirectory(root);
    stderr.writeln("Removed workspace '$name'");

    if (!skipHooks && defaultRoot != null) {
      await runHooks('post-remove', hooks: _config.hooks, name: name, path: defaultRoot);
    }

    if (previousRoot != null) {
      outputCdPath(previousRoot);
    }
  }
}
