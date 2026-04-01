import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dojjo/src/commands/config_command.dart';
import 'package:dojjo/src/commands/copy_ignored_command.dart';
import 'package:dojjo/src/commands/for_each_command.dart';
import 'package:dojjo/src/commands/hook_command.dart';
import 'package:dojjo/src/commands/list_command.dart';
import 'package:dojjo/src/commands/merge_command.dart';
import 'package:dojjo/src/commands/prune_command.dart';
import 'package:dojjo/src/commands/remove_command.dart';
import 'package:dojjo/src/commands/run_command.dart';
import 'package:dojjo/src/commands/shell_command.dart';
import 'package:dojjo/src/commands/switch_command.dart';
import 'package:dojjo/src/commands/update_stale_command.dart';
import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:dojjo/src/version.dart';

Future<void> main(List<String> args) async {
  // Load config from the workspace root, matching worktrunk's behaviour of
  // resolving .config/wt.toml from the worktree root rather than the cwd.
  String? root = await workspaceRoot().ignoreErrors<CommandError>();
  final configWithSource = await loadConfig(projectRoot: root);
  final config = configWithSource.config;

  final runner = _DjoCommandRunner(config, configWithSource);

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } on Exception catch (e) {
    stderr.writeln(e);
    exit(1);
  }
}

class _DjoCommandRunner extends CommandRunner<void> {
  _DjoCommandRunner(Config config, ConfigWithSource configWithSource) : super('djo', 'Manage jj workspaces') {
    argParser
      ..addFlag('verbose', abbr: 'v', defaultsTo: false)
      ..addFlag('version', defaultsTo: false, negatable: false, help: 'Print the dojjo version')
      ..addFlag('porcelain', defaultsTo: false, hide: true, help: 'Machine-readable output for shell integration');
    addCommand(ConfigCommand(configWithSource));
    addCommand(SwitchCommand(config));
    addCommand(MergeCommand(config));
    addCommand(ListCommand());
    addCommand(RemoveCommand(config));
    addCommand(RunCommand(config));
    addCommand(HookCommand(config));
    addCommand(CopyIgnoredCommand(config));
    addCommand(ForEachCommand());
    addCommand(PruneCommand());
    addCommand(UpdateStaleCommand());
    addCommand(ShellCommand());
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.flag('version')) {
      stdout.writeln(version);
      return;
    }
    verbose = topLevelResults.flag('verbose');
    porcelain = topLevelResults.flag('porcelain');
    await super.runCommand(topLevelResults);
  }
}
