import 'dart:convert';
import 'dart:io';

import 'package:dojjo/src/jj.dart' as jj;
import 'package:path/path.dart' as p;

Future<String> _jjDir() async {
  final root = await jj.workspaceRoot();
  return p.join(root, '.jj');
}

// --- Previous workspace ---

Future<String?> loadPreviousWorkspace() async {
  try {
    final path = p.join(await _jjDir(), 'djo-state');
    final file = File(path);
    if (await file.exists()) {
      final content = (await file.readAsString()).trim();
      return content.isNotEmpty ? content : null;
    }
  } on Exception {
    // Best-effort.
  }
  return null;
}

Future<void> savePreviousWorkspace(String name) async {
  try {
    final path = p.join(await _jjDir(), 'djo-state');
    await File(path).writeAsString('$name\n');
  } on Exception {
    // Best-effort.
  }
}

// --- Workspace indices ---

Future<String> _indicesPath() async => p.join(await _jjDir(), 'djo-indices.json');

Future<Map<String, int>> _loadIndices() async {
  try {
    final file = File(await _indicesPath());
    if (await file.exists()) {
      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, Object?>;
      return decoded.map((key, value) => MapEntry(key, value! as int));
    }
  } on Exception {
    // Best-effort.
  }
  return {};
}

Future<void> _saveIndices(Map<String, int> indices) async {
  try {
    await File(await _indicesPath()).writeAsString(jsonEncode(indices));
  } on Exception {
    // Best-effort.
  }
}

/// Returns the persistent index for a workspace, assigning one if needed.
Future<int> workspaceIndex(String name) async {
  final indices = await _loadIndices();
  final existing = indices[name];
  if (existing != null) return existing;

  // Assign the lowest available index.
  final used = indices.values.toSet();
  var index = 0;
  while (used.contains(index)) {
    index++;
  }
  indices[name] = index;
  await _saveIndices(indices);
  return index;
}

/// Removes the index for a workspace, freeing it for reuse.
Future<void> removeWorkspaceIndex(String name) async {
  final indices = await _loadIndices();
  if (indices.remove(name) != null) {
    await _saveIndices(indices);
  }
}
