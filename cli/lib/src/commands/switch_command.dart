import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/prompt.dart' as prompt;

class SwitchCommand extends Command<void> {
  SwitchCommand() {
    argParser.addFlag('create', abbr: 'c', defaultsTo: false);
  }

  @override
  String get name => 'switch';

  @override
  String get description => 'Create or switch to a jj workspace';

  Future<String> _createWorkspace(String name) async {
    final root = await jj.workspaceRoot();
    final path = '$root/../$name';
    await jj.workspaceAdd(path, name);
    await jj.bookmarkCreate(name);
    return path;
  }

  @override
  Future<void> run() async {
    final create = argResults!.flag('create');
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <name>');
    }
    final name = rest.first;

    if (create) {
      final path = await _createWorkspace(name);
      stdout.writeln(path);
      return;
    }

    try {
      final path = await jj.workspaceRoot(name);
      stdout.writeln(path);
    } on jj.CommandError {
      final confirmed =
          await prompt.confirm("Workspace '$name' not found. Create it?");
      if (!confirmed) {
        throw Exception('Aborted');
      }
      final path = await _createWorkspace(name);
      stdout.writeln(path);
    }
  }
}
