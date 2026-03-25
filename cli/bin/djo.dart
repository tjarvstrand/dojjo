import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/commands/list_command.dart';
import 'package:dojjo/src/commands/merge_command.dart';
import 'package:dojjo/src/commands/remove_command.dart';
import 'package:dojjo/src/commands/shell_command.dart';
import 'package:dojjo/src/commands/switch_command.dart';
import 'package:dojjo/src/commands/update_stale_command.dart';
import 'package:dojjo/src/jj.dart' as jj;

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('djo', 'Manage jj workspaces')
    ..argParser.addFlag('verbose', abbr: 'v', defaultsTo: false)
    ..addCommand(SwitchCommand())
    ..addCommand(MergeCommand())
    ..addCommand(ListCommand())
    ..addCommand(RemoveCommand())
    ..addCommand(UpdateStaleCommand())
    ..addCommand(ShellCommand());

  // Parse global flags before running commands.
  final results = runner.argParser.parse(args);
  jj.verbose = results.flag('verbose');

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
