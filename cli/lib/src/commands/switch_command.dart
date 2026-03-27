import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/prompt.dart' as prompt;
import 'package:dojjo/src/template.dart';

class SwitchCommand extends Command<void> {
  SwitchCommand(this._config) {
    argParser.addFlag('create', abbr: 'c', defaultsTo: false);
  }

  final Config _config;

  @override
  String get name => 'switch';

  @override
  String get description => 'Create or switch to a jj workspace';

  Future<String> _createWorkspace(String workspaceName) async {
    final root = await jj.workspaceRoot();
    final path = _config.worktreePath.isNotEmpty
        ? renderTemplate(
            _config.worktreePath,
            name: workspaceName,
            repoPath: root,
          )
        : '$root/../$workspaceName';
    await jj.workspaceAdd(path, workspaceName);
    await jj.bookmarkCreate(workspaceName);
    return path;
  }

  @override
  Future<void> run() async {
    final create = argResults!.flag('create');
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <name>');
    }
    final workspaceName = rest.first;

    if (create) {
      final path = await _createWorkspace(workspaceName);
      stdout.writeln(path);
      return;
    }

    try {
      final path = await jj.workspaceRoot(workspaceName);
      stdout.writeln(path);
    } on jj.CommandError {
      final confirmed =
          await prompt.confirm("Workspace '$workspaceName' not found. Create it?");
      if (!confirmed) {
        throw Exception('Aborted');
      }
      final path = await _createWorkspace(workspaceName);
      stdout.writeln(path);
    }
  }
}
