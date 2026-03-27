import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'package:dojjo/src/commands/config_command.dart';
import 'package:dojjo/src/commands/hook_command.dart';
import 'package:dojjo/src/commands/list_command.dart';
import 'package:dojjo/src/commands/merge_command.dart';
import 'package:dojjo/src/commands/push_command.dart';
import 'package:dojjo/src/commands/remove_command.dart';
import 'package:dojjo/src/commands/shell_command.dart';
import 'package:dojjo/src/commands/switch_command.dart';
import 'package:dojjo/src/commands/update_stale_command.dart';
import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/jj.dart' as jj;

Future<void> main(List<String> args) async {
  // Load config.
  final configWithSource = await loadConfig();
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
  _DjoCommandRunner(Config config, ConfigWithSource configWithSource)
      : super('djo', 'Manage jj workspaces') {
    argParser.addFlag('verbose', abbr: 'v', defaultsTo: false);
    addCommand(ConfigCommand(configWithSource));
    addCommand(SwitchCommand(config));
    addCommand(MergeCommand(config));
    addCommand(PushCommand());
    addCommand(ListCommand());
    addCommand(RemoveCommand(config));
    addCommand(HookCommand(config));
    addCommand(UpdateStaleCommand());
    addCommand(ShellCommand());
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    jj.verbose = topLevelResults.flag('verbose');
    await super.runCommand(topLevelResults);
  }
}
