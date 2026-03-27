import 'dart:convert';

import 'package:dojjo/src/jj.dart';

String formatWorkspace(WorkspaceInfo workspace) {
  final marker = workspace.current ? '* ' : '  ';
  final flags = [if (workspace.conflict) '\u2718', if (workspace.divergent) '\u2195'];
  final flagString = flags.isNotEmpty ? ' ${flags.join(' ')}' : '';
  final bookmarks = workspace.bookmarks.isNotEmpty ? ' [${workspace.bookmarks}]' : '';
  final files = workspace.empty ? '' : ' (${workspace.modifiedFiles} files)';
  final description = workspace.description.isNotEmpty ? ' ${workspace.description}' : '';
  return '$marker${workspace.name}$bookmarks$flagString$description$files';
}

String workspaceListJson(List<WorkspaceInfo> workspaces) =>
    jsonEncode(workspaces.map((workspace) => workspace.toJson()).toList());
