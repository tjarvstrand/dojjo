import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/template.dart';
import 'package:dojjo/src/util/extensions.dart';

class ForEachCommand extends Command<void> {
  @override
  String get name => 'for-each';

  @override
  String get description => 'Run a command in every workspace';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <command>');
    }
    final command = rest.join(' ');

    final workspaces = await workspaceListRich();
    if (workspaces.isEmpty) {
      stderr.writeln('No workspaces found.');
      return;
    }

    for (final workspace in workspaces) {
      final path = await workspaceRoot(workspace.name);
      final rendered = renderTemplate(command, name: workspace.name, repoPath: path);

      stderr.writeln('=== ${workspace.name} ===');

      final result = await runShellCommand(rendered, workingDirectory: path);

      result.stdout?.let(stdout.writeln);
      result.stderr?.let(stderr.writeln);

      if (result.exitCode != 0) {
        stderr.writeln('Failed in ${workspace.name} (exit ${result.exitCode})');
      }
    }
  }
}
