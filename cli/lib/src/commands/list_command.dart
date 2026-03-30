import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/format.dart';
import 'package:dojjo/src/jj.dart';

class ListCommand extends Command<void> {
  ListCommand() {
    argParser
      ..addFlag('json', defaultsTo: false)
      ..addFlag('full', defaultsTo: false, help: 'Show additional details (path, age, diff stats)');
  }

  @override
  String get name => 'list';

  @override
  String get description => 'List all jj workspaces';

  @override
  Future<void> run() async {
    final json = argResults!.flag('json');
    final full = argResults!.flag('full');
    var workspaces = await workspaceListRich();

    if (full && !json) {
      workspaces = await enrichWorkspaces(workspaces);
    }

    if (json) {
      stdout.writeln(workspaceListJson(workspaces));
    } else if (full) {
      stdout.writeln(formatWorkspaceTable(workspaces));
    } else {
      stdout.writeln(workspaces.map(formatWorkspace).join('\n'));
    }
  }
}
