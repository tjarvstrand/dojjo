import 'dart:convert';
import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'jj.freezed.dart';
part 'jj.g.dart';

class CommandError implements Exception {
  CommandError(this.exitCode, this.stderr);

  final int exitCode;
  final String stderr;

  @override
  String toString() => 'jj exited with code $exitCode: $stderr';
}

@freezed
sealed class WorkspaceInfo with _$WorkspaceInfo {
  const factory WorkspaceInfo({
    required String name,
    required String changeId,
    required String bookmarks,
    required String description,
    required bool conflict,
    required bool divergent,
    required bool empty,
    required bool current,
    required int modifiedFiles,
  }) = _WorkspaceInfo;

  factory WorkspaceInfo.fromJson(Map<String, Object?> json) => _$WorkspaceInfoFromJson(json);
}

var verbose = false;

const _listTemplate =
    'self.name() ++ "\\t" ++ self.target().change_id().short() ++ "\\t" ++ '
    'self.target().local_bookmarks().join(",") ++ "\\t" ++ '
    'self.target().description().first_line() ++ "\\t" ++ '
    'self.target().conflict() ++ "\\t" ++ self.target().divergent() ++ "\\t" ++ '
    'self.target().empty() ++ "\\t" ++ self.target().current_working_copy() ++ "\\t" ++ '
    'self.target().diff().files().len() ++ "\\n"';

Future<String> _run(List<String> args) async {
  if (verbose) {
    stderr.writeln('djo: jj ${args.join(' ')}');
  }

  final result = await Process.run('jj', args);

  if (result.exitCode != 0) {
    throw CommandError(result.exitCode, (result.stderr as String).trim());
  }

  final stdout = (result.stdout as String).trim();

  if (verbose && stdout.isNotEmpty) {
    stderr.writeln('djo: $stdout');
  }

  return stdout;
}

List<WorkspaceInfo> parseWorkspaceList(String output) =>
    const LineSplitter().convert(output).where((line) => line.isNotEmpty).map((line) {
      final parts = line.split('\t');
      return WorkspaceInfo(
        name: parts[0],
        changeId: parts[1],
        bookmarks: parts[2],
        description: parts[3],
        conflict: parts[4] == 'true',
        divergent: parts[5] == 'true',
        empty: parts[6] == 'true',
        current: parts[7] == 'true',
        modifiedFiles: int.tryParse(parts[8]) ?? 0,
      );
    }).toList();

Future<String> workspaceAdd(String path, {String? name, String? revision}) => _run([
  'workspace',
  'add',
  if (name != null) ...['--name', name],
  if (revision != null) ...['-r', revision],
  path,
]);

Future<String> workspaceList() => _run(['workspace', 'list']);

Future<List<WorkspaceInfo>> workspaceListRich() async =>
    parseWorkspaceList(await _run(['workspace', 'list', '-T', _listTemplate]));

Future<String> workspaceUpdateStale() => _run(['workspace', 'update-stale']);

Future<String> workspaceForget(String name) => _run(['workspace', 'forget', name]);

Future<String> workspaceRoot([String? name]) => _run([
  'workspace',
  'root',
  if (name != null) ...['--name', name],
]);

Future<String> bookmarkCreate(String name) => _run(['bookmark', 'create', name]);

Future<String> bookmarkDelete(String name) => _run(['bookmark', 'delete', name]);

Future<String> bookmarkSet(String name, String revision) => _run(['bookmark', 'set', name, '-r', revision]);

Future<String> bookmarkTrack(String name, {required String remote}) => _run(['bookmark', 'track', '$name@$remote']);

Future<String> gitPush({String? bookmark, bool all = false}) => _run([
  'git',
  'push',
  if (all) '--all',
  if (bookmark != null && !all) ...['--bookmark', bookmark],
]);

Future<String> squash() => _run(['squash']);

Future<String> rebase(String destination) => _run(['rebase', '-d', destination]);

/// Returns true if the given revset matches any commits.
Future<bool> revsetMatches(String revset) async {
  try {
    final output = await _run(['log', '-r', revset, '--no-graph', '-T', 'empty']);
    return output.isNotEmpty;
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
