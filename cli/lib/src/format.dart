import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:dojjo/src/jj.dart';
import 'package:path/path.dart' as p;

String formatWorkspace(WorkspaceInfo workspace) {
  final marker = workspace.current ? '* ' : '  ';
  final flags = [if (workspace.conflict) '\u2718', if (workspace.divergent) '\u2195'];
  final flagString = flags.isEmpty ? '' : ' ${flags.join(' ')}';
  final bookmarks = workspace.bookmarks.isEmpty ? '' : ' [${workspace.bookmarks.join(',')}]';
  final files = workspace.empty ? '' : ' (${workspace.modifiedFiles} files)';
  final description = workspace.description.isEmpty ? '' : ' ${workspace.description}';
  return '$marker${workspace.name}$bookmarks$flagString$description$files';
}

String formatWorkspaceTable(List<WorkspaceInfo> workspaces) {
  if (workspaces.isEmpty) return '';

  final rows = workspaces.map(_tableRow).toList();
  final headers = ['', 'Name', 'Bookmarks', 'Commit', 'Age', 'Diff', 'Path', 'Description'];

  // Calculate column widths.
  final widths = List.filled(headers.length, 0);
  for (var col = 0; col < headers.length; col++) {
    widths[col] = max(headers[col].length, rows.fold(0, (m, row) => max(m, row[col].length)));
  }

  final buf = StringBuffer();

  // Header.
  buf.writeln(_formatRow(headers, widths));

  // Rows.
  for (final row in rows) {
    buf.writeln(_formatRow(row, widths));
  }

  return buf.toString().trimRight();
}

List<String> _tableRow(WorkspaceInfo workspace) {
  final marker = workspace.current ? '*' : '';
  final flags = [if (workspace.conflict) '\u2718', if (workspace.divergent) '\u2195'];
  final flagString = flags.isEmpty ? '' : ' ${flags.join(' ')}';
  final diff = workspace.empty && workspace.insertions == 0 && workspace.deletions == 0
      ? ''
      : '+${workspace.insertions} -${workspace.deletions}';
  final shortPath = workspace.path.isEmpty ? '' : _shortenPath(workspace.path);

  return [
    marker,
    '${workspace.name}$flagString',
    workspace.bookmarks.join(','),
    workspace.changeId,
    workspace.age,
    diff,
    shortPath,
    workspace.description,
  ];
}

String _formatRow(List<String> cells, List<int> widths) {
  final parts = <String>[];
  for (var i = 0; i < cells.length; i++) {
    parts.add(cells[i].padRight(widths[i]));
  }
  return parts.join('  ').trimRight();
}

/// Shorten a path by replacing the home directory with ~.
String _shortenPath(String path) {
  final home = p.context.style == p.Style.windows ? Platform.environment['USERPROFILE'] : Platform.environment['HOME'];
  if (home != null && path.startsWith(home)) {
    return '~${path.substring(home.length)}';
  }
  return path;
}

String workspaceListJson(List<WorkspaceInfo> workspaces) =>
    jsonEncode(workspaces.map((workspace) => workspace.toJson()).toList());
