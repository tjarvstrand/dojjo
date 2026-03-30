import 'package:args/command_runner.dart';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart';
import 'package:dojjo/src/jj.dart';

class RunCommand extends Command<void> {
  RunCommand(this._config);

  final Config _config;

  @override
  String get name => 'run';

  @override
  String get description => 'Run a configured alias command';

  @override
  String get invocation => '${runner!.executableName} $name <alias>';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException(
        'Missing required argument: <alias>\n'
        'Available aliases: ${_config.aliases.keys.join(', ')}',
      );
    }
    final alias = rest.first;

    final pipeline = _config.aliases[alias];
    if (pipeline == null) {
      throw Exception(
        'Unknown alias "$alias".\n'
        'Available aliases: ${_config.aliases.keys.join(', ')}',
      );
    }

    final root = await workspaceRoot();
    final workspaces = await workspaceListRich();
    final current = workspaces.where((workspace) => workspace.current).firstOrNull;
    final workspaceName = current?.name ?? 'default';

    await runAlias(alias, pipeline: pipeline, name: workspaceName, path: root);
  }
}
