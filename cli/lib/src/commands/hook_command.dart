import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart' as hooks;
import 'package:dojjo/src/jj.dart' as jj;

class HookCommand extends Command<void> {
  HookCommand(this._config);

  final Config _config;

  @override
  String get name => 'hook';

  @override
  String get description => 'Manually run hooks for a given type';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException(
        'Missing required argument: <type>\n'
        'Available types: ${_config.hooks.keys.join(', ')}',
      );
    }
    final hookType = rest.first;

    if (!_config.hooks.containsKey(hookType)) {
      stderr.writeln('No hooks configured for "$hookType".');
      return;
    }

    final root = await jj.workspaceRoot();
    final workspaces = await jj.workspaceListRich();
    final current =
        workspaces.where((workspace) => workspace.current).firstOrNull;
    final workspaceName = current?.name ?? 'default';

    await hooks.runHooks(
      hookType,
      hooks: _config.hooks,
      name: workspaceName,
      path: root,
    );
  }
}
