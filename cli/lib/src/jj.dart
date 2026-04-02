import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'jj.freezed.dart';
part 'jj.g.dart';

class CommandError implements Exception {
  CommandError(this.exitCode, this.stderr);

  final int exitCode;
  final String? stderr;

  @override
  String toString() => 'jj exited with code $exitCode${stderr == null ? '' : ': $stderr'}';
}

@freezed
sealed class WorkspaceInfo with _$WorkspaceInfo {
  const factory WorkspaceInfo({
    required String name,
    required String changeId,
    required List<String> bookmarks,
    required String description,
    required bool conflict,
    required bool divergent,
    required bool empty,
    required bool current,
    required int modifiedFiles,
    @Default('') String age,
    @Default('') String path,
    @Default(0) int insertions,
    @Default(0) int deletions,
  }) = _WorkspaceInfo;

  factory WorkspaceInfo.fromJson(Map<String, Object?> json) => _$WorkspaceInfoFromJson(json);
}

var verbose = false;
var porcelain = false;

/// Write a path to stdout that the shell wrapper should cd into.
/// In porcelain mode, prefixes with `cd:` so the wrapper can parse it.
/// In normal mode, just prints the path.
void outputCdPath(String path) {
  if (porcelain) {
    stdout.writeln('cd:$path');
  } else {
    stdout.writeln(path);
  }
}

const _listTemplate =
    'self.name() ++ "\\t" ++ self.target().change_id().short() ++ "\\t" ++ '
    'self.target().local_bookmarks().join(",") ++ "\\t" ++ '
    'self.target().description().first_line() ++ "\\t" ++ '
    'self.target().conflict() ++ "\\t" ++ self.target().divergent() ++ "\\t" ++ '
    'self.target().empty() ++ "\\t" ++ self.target().current_working_copy() ++ "\\t" ++ '
    'self.target().diff().files().len() ++ "\\t" ++ '
    'self.target().committer().timestamp().ago() ++ "\\n"';

Future<ShellResult> _run(List<String> args) async {
  if (verbose) {
    stderr.writeln('djo: jj ${args.join(' ')}');
  }

  final result = await runProcess(
    'jj',
    args,
  ).onError<ProcessException>((e, _) => throw CommandError(-1, 'Failed to run jj: ${e.message}'));

  if (result.exitCode != 0) {
    throw CommandError(result.exitCode, result.stderr);
  }

  if (verbose) {
    result.stdout?.let((out) => stderr.writeln('djo: $out'));
  }

  return result;
}

List<WorkspaceInfo> parseWorkspaceList(String output) => output.nonEmptyLines.map((line) {
  final parts = line.split('\t');
  if (parts.length != 10) {
    throw FormatException('Expected 10 tab-separated fields from jj workspace list, got ${parts.length}: $line');
  }
  return WorkspaceInfo(
    name: parts[0],
    changeId: parts[1],
    bookmarks: parts[2].split(',').where((bookmark) => bookmark.isNotEmpty).toList(),
    description: parts[3],
    conflict: parts[4] == 'true',
    divergent: parts[5] == 'true',
    empty: parts[6] == 'true',
    current: parts[7] == 'true',
    modifiedFiles: int.tryParse(parts[8]) ?? 0,
    age: parts[9],
  );
}).toList();

Future<void> workspaceAdd(String path, {String? name, String? revision}) => _run([
  'workspace',
  'add',
  if (name != null) ...['--name', name],
  if (revision != null) ...['-r', revision],
  path,
]);

Future<String?> workspaceList() async => (await _run(['workspace', 'list'])).stdout;

Future<List<WorkspaceInfo>> workspaceListRich() async {
  final result = await _run(['workspace', 'list', '-T', _listTemplate]);
  return result.stdout?.let(parseWorkspaceList) ?? [];
}

/// Parse a jj diff.stat() summary line like "8 files changed, 148 insertions(+), 36 deletions(-)".
({int insertions, int deletions}) parseDiffStatSummary(String summary) => (
  insertions: RegExp(r'(\d+) insertions?\(\+\)').firstMatch(summary)?.group(1)?.let(int.parse) ?? 0,
  deletions: RegExp(r'(\d+) deletions?\(-\)').firstMatch(summary)?.group(1)?.let(int.parse) ?? 0,
);

/// Fetch paths and diff stats for all workspaces in parallel.
Future<List<WorkspaceInfo>> enrichWorkspaces(List<WorkspaceInfo> workspaces) async {
  // Fetch paths in parallel.
  final pathFutures = workspaces.map((workspace) async {
    try {
      return await workspaceRoot(workspace.name);
    } on CommandError {
      return '';
    }
  });
  final paths = await Future.wait(pathFutures);

  // Fetch diff stats for all working copies in one jj call.
  // Each workspace's stat output ends with a summary line, separated by a marker.
  final result = await _run([
    'log',
    '-r',
    'working_copies()',
    '--no-graph',
    '-T',
    r'change_id.short() ++ "\t" ++ diff.stat(0) ++ "===\n"',
  ]).ignoreErrors<CommandError>();

  final diffStats =
      result?.stdout
          ?.split('===\n')
          .expand((block) sync* {
            final trimmed = block.trim();
            if (trimmed.isEmpty) return;
            final lines = trimmed.split('\n');
            // First line starts with changeId\t
            final firstTab = lines.first.indexOf('\t');
            if (firstTab == -1) return;
            final changeId = lines.first.substring(0, firstTab);
            // Summary is the last line.
            final summary = lines.last;
            yield MapEntry(changeId, parseDiffStatSummary(summary));
          })
          .let(Map.fromEntries) ??
      {};

  return workspaces
      .mapIndexed(
        (index, workspace) => workspace.copyWith(
          path: paths[index],
          insertions: diffStats[workspace.changeId]?.insertions ?? 0,
          deletions: diffStats[workspace.changeId]?.deletions ?? 0,
        ),
      )
      .toList();
}

Future<String?> workspaceUpdateStale() async => (await _run(['workspace', 'update-stale'])).stdout;

Future<void> workspaceForget(String name) => _run(['workspace', 'forget', name]);

Future<String> workspaceRoot([String? name]) async {
  final stdout = (await _run([
    'workspace',
    'root',
    if (name != null) ...['--name', name],
  ])).stdout;
  if (stdout == null) {
    throw CommandError(-1, 'jj workspace root returned empty output');
  }
  return stdout;
}

Future<void> bookmarkCreate(String name, {String? revision}) => _run([
  'bookmark',
  'create',
  if (revision != null) ...['-r', revision],
  name,
]);

Future<void> bookmarkDelete(String name) => _run(['bookmark', 'delete', name]);

Future<void> abandon(String revset) => _run(['abandon', revset]);

Future<void> bookmarkSet(String name, String revision) => _run(['bookmark', 'set', name, '-r', revision]);

Future<void> bookmarkTrack(String name, {required String remote}) => _run(['bookmark', 'track', '$name@$remote']);

Future<String?> gitPush({String? bookmark, bool all = false}) async => (await _run([
  'git',
  'push',
  if (all) '--all',
  if (bookmark != null && !all) ...['--bookmark', bookmark],
])).stdout;

Future<String> logTemplate(String revset, String template) async {
  final stdout = (await _run(['log', '-r', revset, '--no-graph', '-T', template])).stdout;
  if (stdout == null) {
    throw CommandError(-1, 'jj log returned empty output');
  }
  return stdout;
}

Future<String?> gitRemoteList() async => (await _run(['git', 'remote', 'list'])).stdout;

Future<void> squash() => _run(['squash']);

Future<void> rebase(String destination) => _run(['rebase', '-d', destination]);

/// Returns true if the given revset matches any commits.
Future<bool> revsetMatches(String revset) async {
  try {
    final result = await _run(['log', '-r', revset, '--no-graph', '-T', 'empty']);
    return result.stdout?.isNotEmpty ?? false;
  } on CommandError {
    return false;
  }
}

Future<void> deleteDirectory(String path) async {
  final dir = Directory(path);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}
