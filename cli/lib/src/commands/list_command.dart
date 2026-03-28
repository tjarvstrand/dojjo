import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/format.dart';
import 'package:dojjo/src/jj.dart';

class ListCommand extends Command<void> {
  ListCommand() {
    argParser.addFlag('json', defaultsTo: false);
  }

  @override
  String get name => 'list';

  @override
  String get description => 'List all jj workspaces';

  @override
  Future<void> run() async {
    final json = argResults!.flag('json');
    final workspaces = await workspaceListRich();

    if (json) {
      stdout.writeln(workspaceListJson(workspaces));
    } else {
      stdout.writeln(workspaces.map(formatWorkspace).join('\n'));
    }
  }
}
