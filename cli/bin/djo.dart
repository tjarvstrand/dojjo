import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'package:dojjo/src/commands/config_command.dart';
import 'package:dojjo/src/commands/list_command.dart';
import 'package:dojjo/src/commands/merge_command.dart';
import 'package:dojjo/src/commands/remove_command.dart';
import 'package:dojjo/src/commands/shell_command.dart';
import 'package:dojjo/src/commands/switch_command.dart';
import 'package:dojjo/src/commands/update_stale_command.dart';
import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/jj.dart' as jj;

Future<void> main(List<String> args) async {
  // Parse global flags early.
  final globalParser = ArgParser()
    ..addFlag('verbose', abbr: 'v', defaultsTo: false);
  final globalResults = globalParser.parse(args);
  jj.verbose = globalResults.flag('verbose');

  // Load config.
  final configWithSource = await loadConfig();
  final config = configWithSource.config;

  final runner = CommandRunner<void>('djo', 'Manage jj workspaces')
    ..argParser.addFlag('verbose', abbr: 'v', defaultsTo: false)
    ..addCommand(ConfigCommand(configWithSource))
    ..addCommand(SwitchCommand(config))
    ..addCommand(MergeCommand(config))
    ..addCommand(ListCommand())
    ..addCommand(RemoveCommand())
    ..addCommand(UpdateStaleCommand())
    ..addCommand(ShellCommand());

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
