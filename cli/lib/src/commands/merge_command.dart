import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart' as hooks;
import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/prompt.dart' as prompt;
import 'package:path/path.dart' as p;

class MergeCommand extends Command<void> {
  MergeCommand(this._config) {
    argParser
      ..addFlag('yes', abbr: 'y', defaultsTo: false)
      ..addFlag('push', defaultsTo: false, help: 'Push target bookmark after merge')
      ..addFlag('skip-hooks', defaultsTo: false, help: 'Skip hooks');
  }

  final Config _config;

  @override
  String get name => 'merge';

  @override
  String get description => 'Squash, rebase onto target, move bookmark, and clean up workspace';

  Future<void> _step(String name, Future<String> Function() effect) async {
    try {
      await effect();
    } on Exception catch (err) {
      stderr.writeln('Failed during $name: $err');
      stderr.writeln("Run 'jj op undo' to revert changes made so far");
      rethrow;
    }
  }

  @override
  Future<void> run() async {
    final yes = argResults!.flag('yes');
    final skipHooks = argResults!.flag('skip-hooks');
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <target>');
    }
    final target = rest.first;

    final root = await jj.workspaceRoot();
    stderr.writeln("Will squash, rebase onto '$target', move bookmark, and delete $root");
    await prompt.confirmOrAbort('Proceed?', yes: yes);

    if (!skipHooks) {
      await hooks.runHooks('pre-merge', hooks: _config.hooks, name: target, path: root);
    }

    if (_config.merge.squash) {
      await _step('squash', jj.squash);
    }
    if (_config.merge.rebase) {
      await _step('rebase', () => jj.rebase(target));
    }
    await _step('bookmark set', () => jj.bookmarkSet(target, '@-'));
    await _step('workspace forget', () => jj.workspaceForget('@'));
    if (_config.merge.remove) {
      await jj.deleteDirectory(root);
    }

    final shouldPush = argResults!.flag('push') || _config.merge.push;
    if (shouldPush) {
      await _step('push', () => jj.gitPush(bookmark: target));
    }

    final parentDir = p.dirname(root);
    stdout.writeln(parentDir);

    if (!skipHooks) {
      await hooks.runHooks('post-merge', hooks: _config.hooks, name: target, path: parentDir);
    }
  }
}
