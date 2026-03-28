import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/util/extensions.dart';

class UpdateStaleCommand extends Command<void> {
  @override
  String get name => 'update-stale';

  @override
  String get description => 'Update workspaces with stale working copies';

  @override
  Future<void> run() async {
    (await workspaceUpdateStale())?.let(stdout.writeln);
  }
}
