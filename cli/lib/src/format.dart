import 'dart:convert';

import 'package:dojjo/src/jj.dart';

String formatWorkspace(WorkspaceInfo ws) {
  final marker = ws.current ? '* ' : '  ';
  final flags = [
    if (ws.conflict) '\u2718',
    if (ws.divergent) '\u2195',
  ];
  final flagStr = flags.isNotEmpty ? ' ${flags.join(' ')}' : '';
  final bm = ws.bookmarks.isNotEmpty ? ' [${ws.bookmarks}]' : '';
  final files = ws.empty ? '' : ' (${ws.modifiedFiles} files)';
  final desc = ws.description.isNotEmpty ? ' ${ws.description}' : '';
  return '$marker${ws.name}$bm$flagStr$desc$files';
}

String workspaceListJson(List<WorkspaceInfo> workspaces) =>
    jsonEncode(workspaces.map((ws) => ws.toJson()).toList());
