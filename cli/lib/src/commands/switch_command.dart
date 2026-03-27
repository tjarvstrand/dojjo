import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart' as hooks;
import 'package:dojjo/src/jj.dart' as jj;
import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/prompt.dart' as prompt;
import 'package:dojjo/src/state.dart' as state;
import 'package:dojjo/src/template.dart';
import 'package:path/path.dart' as p;

class SwitchCommand extends Command<void> {
  SwitchCommand(this._config) {
    argParser
      ..addFlag('create', abbr: 'c', defaultsTo: false)
      ..addFlag('skip-hooks', defaultsTo: false, help: 'Skip hooks')
      ..addOption('base', abbr: 'b', help: 'Base revision for new workspace')
      ..addOption('execute', abbr: 'x', help: 'Command to run in workspace after switching');
  }

  final Config _config;

  @override
  String get name => 'switch';

  @override
  String get description => 'Create or switch to a jj workspace';

  Future<String> _createWorkspace(String name, {String? revision}) async {
    final root = await jj.workspaceRoot();
    final index = await state.workspaceIndex(name);
    final path = _config.worktreePath.isNotEmpty
        ? renderTemplate(_config.worktreePath, name: name, repoPath: root, workspaceIndex: index)
        : p.join(root, '..', name);
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
    final rendered = renderTemplate(command, name: p.basename(path), repoPath: path);
    final result = await runShellCommand(rendered, workingDirectory: path);
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

    final lines = workspaces.map((workspace) => workspace.name).toList();
    final input = lines.join('\n');

    // Try fzf first.
    try {
      final result = await Process.start('fzf', ['--prompt', 'workspace> ']);
      result.stdin.write(input);
      await result.stdin.close();
      final output = await result.stdout.transform(const SystemEncoding().decoder).join();
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

  Future<void> _runHook(String hookType, String name, String path, {int? workspaceIndex}) async {
    if (argResults!.flag('skip-hooks')) return;
    await hooks.runHooks(hookType, hooks: _config.hooks, name: name, path: path, workspaceIndex: workspaceIndex);
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
    final current = workspaces.where((workspace) => workspace.current).firstOrNull;
    if (current != null) {
      await state.savePreviousWorkspace(current.name);
    }

    String path;
    if (create) {
      await _runHook('pre-start', name, '.');
      path = await _createWorkspace(name, revision: base);
      final index = await state.workspaceIndex(name);
      stdout.writeln(path);
      await _runHook('post-start', name, path, workspaceIndex: index);
    } else {
      await _runHook('pre-switch', name, '.');
      try {
        path = await jj.workspaceRoot(name);
      } on jj.CommandError {
        final confirmed = await prompt.confirm("Workspace '$name' not found. Create it?");
        if (!confirmed) {
          throw Exception('Aborted');
        }
        await _runHook('pre-start', name, '.');
        path = await _createWorkspace(name, revision: base);
        final index = await state.workspaceIndex(name);
        stdout.writeln(path);
        await _runHook('post-start', name, path, workspaceIndex: index);
        await _runHook('post-switch', name, path, workspaceIndex: index);

        if (execute != null) {
          await _executeInWorkspace(execute, path);
        }
        return;
      }
      final index = await state.workspaceIndex(name);
      stdout.writeln(path);
      await _runHook('post-switch', name, path, workspaceIndex: index);
    }

    if (execute != null) {
      await _executeInWorkspace(execute, path);
    }
  }
}
