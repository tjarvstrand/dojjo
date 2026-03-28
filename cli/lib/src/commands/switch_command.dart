import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart';
import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/prompt.dart';
import 'package:dojjo/src/state.dart';
import 'package:dojjo/src/template.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:path/path.dart' as p;

class SwitchCommand extends Command<void> {
  SwitchCommand(this._config) {
    argParser
      ..addFlag('create', abbr: 'c', defaultsTo: false)
      ..addFlag('bookmark', defaultsTo: _config.createBookmark, help: 'Create a bookmark for the new workspace')
      ..addFlag('skip-hooks', defaultsTo: false, help: 'Skip hooks')
      ..addOption('base', abbr: 'b', help: 'Base revision for new workspace (defaults to current working-copy parents)')
      ..addOption('execute', abbr: 'x', help: 'Command to run in workspace after switching');
  }

  final Config _config;

  @override
  String get name => 'switch';

  @override
  String get description => 'Create or switch to a jj workspace (use "-" for previous workspace)';

  Future<String> _createWorkspace(String name, {String? revision, required bool createBookmark}) async {
    final root = await workspaceRoot();
    final path = _config.workspacePath.isNotEmpty
        ? renderTemplate(_config.workspacePath, name: name, repoPath: root)
        : p.join(root, '..', name);
    await workspaceAdd(path, name: name, revision: revision);
    if (createBookmark) {
      await bookmarkCreate(name);
      try {
        await bookmarkTrack(name, remote: 'origin');
      } on CommandError {
        // Remote may not exist yet — that's fine.
      }
    }
    return path;
  }

  Future<void> _executeInWorkspace(String command, String path) async {
    final rendered = renderTemplate(command, name: p.basename(path), repoPath: path);
    final result = await runShellCommand(rendered, workingDirectory: path);
    result.stdout?.let(stderr.writeln);
    result.stderr?.let(stderr.writeln);
  }

  Future<String?> _pickWorkspace() async {
    final workspaces = await workspaceListRich();
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
    lines.forEachIndexed((i, line) => stderr.writeln('  ${i + 1}) $line'));

    stderr.write('Select workspace [1-${lines.length}]: ');
    final index = stdin.readLineSync()?.let(int.tryParse);
    if (index == null || index < 1 || index > lines.length) {
      return null;
    }
    return lines[index - 1];
  }

  Future<void> _runHook(String hookType, String name, String path) async {
    if (argResults!.flag('skip-hooks')) return;
    await runHooks(hookType, hooks: _config.hooks, name: name, path: path);
  }

  Future<String> _previousWorkspace() async {
    final previous = await loadPreviousWorkspace();
    if (previous == null) {
      throw Exception('No previous workspace.');
    }
    return previous;
  }

  @override
  Future<void> run() async {
    final create = argResults!.flag('create');
    final bookmark = argResults!.flag('bookmark');
    final base = argResults!.option('base');
    final execute = argResults!.option('execute');
    final rest = argResults!.rest;

    if (rest.isEmpty && create) {
      usageException('Missing required argument: <name>');
    }

    final nameArg = rest.firstOrNull ?? (await _pickWorkspace() ?? (throw Exception('Aborted')));
    final name = nameArg == '-' ? await _previousWorkspace() : nameArg;

    // Save current workspace as "previous" before switching.
    final workspaces = await workspaceListRich();
    await workspaces.where((workspace) => workspace.current).firstOrNull?.name.let(savePreviousWorkspace);

    String path;
    if (create) {
      await _runHook('pre-start', name, '.');
      path = await _createWorkspace(name, revision: base, createBookmark: bookmark);
      stdout.writeln(path);
      await _runHook('post-start', name, path);
    } else {
      await _runHook('pre-switch', name, '.');
      try {
        path = await workspaceRoot(name);
      } on CommandError {
        final confirmed = await confirm("Workspace '$name' not found. Create it?");
        if (!confirmed) {
          throw Exception('Aborted');
        }
        await _runHook('pre-start', name, '.');
        path = await _createWorkspace(name, revision: base, createBookmark: bookmark);
        stdout.writeln(path);
        await _runHook('post-start', name, path);
        await _runHook('post-switch', name, path);

        if (execute != null) {
          await _executeInWorkspace(execute, path);
        }
        return;
      }
      stdout.writeln(path);
      await _runHook('post-switch', name, path);
    }

    if (execute != null) {
      await _executeInWorkspace(execute, path);
    }
  }
}
