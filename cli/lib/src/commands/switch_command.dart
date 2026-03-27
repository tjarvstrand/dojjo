import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/prompt.dart' as prompt;
import 'package:dojjo/src/state.dart' as state;
import 'package:dojjo/src/template.dart';

class SwitchCommand extends Command<void> {
  SwitchCommand(this._config) {
    argParser
      ..addFlag('create', abbr: 'c', defaultsTo: false)
      ..addOption('base', abbr: 'b', help: 'Base revision for new workspace')
      ..addOption(
        'execute',
        abbr: 'x',
        help: 'Command to run in workspace after switching',
      );
  }

  final Config _config;

  @override
  String get name => 'switch';

  @override
  String get description => 'Create or switch to a jj workspace';

  Future<String> _createWorkspace(String name, {String? revision}) async {
    final root = await jj.workspaceRoot();
    final path = _config.worktreePath.isNotEmpty
        ? renderTemplate(
            _config.worktreePath,
            name: name,
            repoPath: root,
          )
        : '$root/../$name';
    await jj.workspaceAdd(path, name: name, revision: revision);
    await jj.bookmarkCreate(name);
    try {
      await jj.bookmarkTrack(name, remote: 'origin');
    } on jj.CommandError {
      // Remote may not exist yet — that's fine.
    }
    return path;
  }

  Future<void> _executeInWorkspace(String command, String path) async {
    final rendered = renderTemplate(
      command,
      name: path.split('/').last,
      repoPath: path,
    );
    final result = await Process.run(
      'sh',
      ['-c', rendered],
      workingDirectory: path,
    );
    final output = (result.stdout as String).trim();
    if (output.isNotEmpty) {
      stderr.writeln(output);
    }
    final error = (result.stderr as String).trim();
    if (error.isNotEmpty) {
      stderr.writeln(error);
    }
  }

  Future<String?> _pickWorkspace() async {
    final workspaces = await jj.workspaceListRich();
    if (workspaces.isEmpty) {
      stderr.writeln('No workspaces found.');
      return null;
    }

    final lines =
        workspaces.map((workspace) => workspace.name).toList();
    final input = lines.join('\n');

    // Try fzf first.
    try {
      final result = await Process.start(
        'fzf',
        ['--prompt', 'workspace> '],
      );
      result.stdin.write(input);
      await result.stdin.close();
      final output = await result.stdout
          .transform(const SystemEncoding().decoder)
          .join();
      final exitCode = await result.exitCode;
      if (exitCode == 0) {
        return output.trim();
      }
      // fzf exit code 130 = user cancelled
      if (exitCode == 130) return null;
    } on ProcessException {
      // fzf not found — fall through to simple picker.
    }

    // Fallback: numbered list.
    for (var i = 0; i < lines.length; i++) {
      stderr.writeln('  ${i + 1}) ${lines[i]}');
    }
    stderr.write('Select workspace [1-${lines.length}]: ');
    final input2 = stdin.readLineSync();
    final index = int.tryParse(input2 ?? '');
    if (index == null || index < 1 || index > lines.length) {
      return null;
    }
    return lines[index - 1];
  }

  @override
  Future<void> run() async {
    final create = argResults!.flag('create');
    final base = argResults!.option('base');
    final execute = argResults!.option('execute');
    final rest = argResults!.rest;

    if (rest.isEmpty && create) {
      usageException('Missing required argument: <name>');
    }

    String name;
    if (rest.isEmpty) {
      final picked = await _pickWorkspace();
      if (picked == null) {
        throw Exception('Aborted');
      }
      name = picked;
    } else {
      name = rest.first;
    }
    if (name == '-') {
      final previous = await state.loadPreviousWorkspace();
      if (previous == null) {
        stderr.writeln('No previous workspace.');
        exit(1);
      }
      name = previous;
    }

    // Save current workspace as "previous" before switching.
    final workspaces = await jj.workspaceListRich();
    final current =
        workspaces.where((workspace) => workspace.current).firstOrNull;
    if (current != null) {
      await state.savePreviousWorkspace(current.name);
    }

    String path;
    if (create) {
      path = await _createWorkspace(name, revision: base);
    } else {
      try {
        path = await jj.workspaceRoot(name);
      } on jj.CommandError {
        final confirmed =
            await prompt.confirm("Workspace '$name' not found. Create it?");
        if (!confirmed) {
          throw Exception('Aborted');
        }
        path = await _createWorkspace(name, revision: base);
      }
    }

    stdout.writeln(path);

    if (execute != null) {
      await _executeInWorkspace(execute, path);
    }
  }
}
