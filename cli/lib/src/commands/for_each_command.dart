import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/template.dart';

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

    final workspaces = await jj.workspaceListRich();
    if (workspaces.isEmpty) {
      stderr.writeln('No workspaces found.');
      return;
    }

    for (final workspace in workspaces) {
      final path = await jj.workspaceRoot(workspace.name);
      final rendered = renderTemplate(command, name: workspace.name, repoPath: path);

      stderr.writeln('=== ${workspace.name} ===');

      final result = await runShellCommand(rendered, workingDirectory: path);

      final output = (result.stdout as String).trim();
      if (output.isNotEmpty) {
        stdout.writeln(output);
      }

      final error = (result.stderr as String).trim();
      if (error.isNotEmpty) {
        stderr.writeln(error);
      }

      if (result.exitCode != 0) {
        stderr.writeln('Failed in ${workspace.name} (exit ${result.exitCode})');
      }
    }
  }
}
