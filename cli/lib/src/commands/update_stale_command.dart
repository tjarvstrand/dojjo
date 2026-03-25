import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/jj.dart' as jj;

class UpdateStaleCommand extends Command<void> {
  @override
  String get name => 'update-stale';

  @override
  String get description => 'Update workspaces with stale working copies';

  @override
  Future<void> run() async {
    final output = await jj.workspaceUpdateStale();
    if (output.isNotEmpty) {
      stdout.writeln(output);
    }
  }
}
