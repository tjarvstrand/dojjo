import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/jj.dart';
import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:path/path.dart' as p;

/// Built-in directories that are always excluded from copying.
const _builtinExcludes = [
  '.bzr',
  '.conductor',
  '.entire',
  '.git',
  '.hg',
  '.jj',
  '.pi',
  '.pijul',
  '.sl',
  '.svn',
  '.worktrees',
];

class CopyIgnoredCommand extends Command<void> {
  CopyIgnoredCommand(this._config) {
    argParser
      ..addOption('from', help: 'Source workspace name')
      ..addOption('to', help: 'Target workspace name (default: current)')
      ..addFlag('dry-run', defaultsTo: false, help: 'Preview without copying')
      ..addFlag('force', defaultsTo: false, help: 'Overwrite existing files in target');
  }

  final Config _config;

  @override
  String get name => 'copy-ignored';

  @override
  String get description =>
      'Copy untracked files (build caches, node_modules, etc.) '
      'from one workspace to another';

  @override
  Future<void> run() async {
    final from = argResults!.option('from') ?? argResults!.rest.firstOrNull;
    if (from == null) {
      usageException('Missing required argument: --from <workspace>');
    }

    final to = argResults!.option('to') ?? (argResults!.rest.length > 1 ? argResults!.rest[1] : null);

    final dryRun = argResults!.flag('dry-run');
    final force = argResults!.flag('force');

    final sourcePath = await workspaceRoot(from);
    final targetPath = to != null ? await workspaceRoot(to) : await workspaceRoot();

    final untrackedFiles = await _listUntracked(sourcePath);
    if (untrackedFiles.isEmpty) {
      stderr.writeln('No untracked files found in $from.');
      return;
    }

    // Apply .worktreeinclude filter if present.
    final includePatterns = await _loadWorktreeInclude(sourcePath);
    final filtered = includePatterns.isNotEmpty
        ? untrackedFiles.where((file) => _matchesAny(file, includePatterns)).toList()
        : untrackedFiles;

    // Group to top-level entries for efficient copying.
    final topLevel = {for (final path in filtered) p.split(path).first};
    final excludes = _allExcludes();

    var copied = 0;
    for (final entry in topLevel) {
      if (excludes.contains(entry)) continue;

      final source = p.join(sourcePath, entry);
      final target = p.join(targetPath, entry);

      if (!await FileSystemEntity.isDirectory(source) && !await FileSystemEntity.isFile(source)) {
        continue;
      }

      // Skip existing unless --force.
      final targetExists = await FileSystemEntity.isDirectory(target) || await FileSystemEntity.isFile(target);
      if (targetExists && !force) {
        if (dryRun) {
          stderr.writeln('  [skip] $entry (exists)');
        }
        continue;
      }

      if (dryRun) {
        stderr.writeln('  [copy] $entry');
        copied++;
        continue;
      }

      if (targetExists) {
        if (await FileSystemEntity.isDirectory(target)) {
          await Directory(target).delete(recursive: true);
        } else {
          await File(target).delete();
        }
      }

      await _copy(source, target);
      copied++;
      stderr.writeln('  $entry');
    }

    final verb = dryRun ? 'Would copy' : 'Copied';
    stderr.writeln('$verb $copied entries from $from.');
  }

  List<String> _allExcludes() => [
    ..._builtinExcludes,
    ..._config.copyIgnored.exclude.map(
      // Ignore-files use / on all platforms
      (pattern) => pattern.endsWith('/') ? pattern.substring(0, pattern.length - 1) : pattern,
    ),
  ];

  bool _matchesAny(String path, List<String> patterns) => patterns.any((pattern) {
    // Ignore-files use / on all platforms
    if (pattern.endsWith('/')) {
      return path.startsWith(pattern) || path.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return path == pattern || path.startsWith('$pattern/');
  });

  Future<List<String>> _loadWorktreeInclude(String workspacePath) async {
    final file = File(p.join(workspacePath, '.worktreeinclude'));
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return content.nonEmptyLines.where((line) => !line.startsWith('#')).toList();
  }

  Future<List<String>> _listUntracked(String workspacePath) async {
    final allFiles = _listFilesRecursive(workspacePath, workspacePath, _allExcludes());

    final result = await runProcess('jj', ['file', 'list'], workingDirectory: workspacePath);
    if (result.exitCode != 0) {
      result.stderr?.let(stderr.writeln);
      return [];
    }
    final tracked = result.stdout?.nonEmptyLines.toSet() ?? {};

    return allFiles.where((file) => !tracked.contains(file)).toList();
  }

  Iterable<String> _listFilesRecursive(String root, String current, List<String> excludes) =>
      Directory(current).listSync().expand((entity) sync* {
        final relative = p.relative(entity.path, from: root);
        final topLevel = p.split(relative).first;
        if (excludes.contains(topLevel)) return;
        if (entity is File) {
          yield relative;
        } else if (entity is Directory) {
          yield* _listFilesRecursive(root, entity.path, excludes);
        }
      });

  Future<void> _copy(String source, String target) async {
    await Directory(p.dirname(target)).create(recursive: true);
    final result = await _runCopy(source, target);
    final failed = Platform.isWindows ? result.exitCode > 7 : result.exitCode != 0;
    if (failed) {
      stderr.writeln('Failed to copy $source: ${result.stderr}');
    }
  }

  Future<ShellResult> _runCopy(String source, String target) {
    if (Platform.isWindows) {
      // robocopy uses exit code 1 for success with files copied.
      return runProcess('robocopy', [source, target, '/E', '/NFL', '/NDL', '/NJH', '/NJS']);
    }
    return runProcess('cp', ['-R', if (Platform.isMacOS) '-c', source, target]);
  }
}
