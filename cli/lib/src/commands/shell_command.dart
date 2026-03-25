import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/shell_integration.dart' as shell;

class ShellCommand extends Command<void> {
  ShellCommand() {
    addSubcommand(ShellInitCommand());
    addSubcommand(ShellInstallCommand());
  }

  @override
  String get name => 'shell';

  @override
  String get description => 'Shell integration commands';
}

class ShellInitCommand extends Command<void> {
  @override
  String get name => 'init';

  @override
  String get description =>
      'Output shell integration code (bash, zsh, or fish)';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <shell>');
    }
    stdout.writeln(shell.initScript(rest.first));
  }
}

class ShellInstallCommand extends Command<void> {
  @override
  String get name => 'install';

  @override
  String get description => 'Add shell integration to rc file';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <shell>');
    }
    final shellName = rest.first;
    final path =
        rest.length > 1 ? rest[1] : shell.defaultRcFile(shellName);
    await shell.install(shellName, path);
    stdout.writeln('Added djo shell integration to $path');
  }
}
