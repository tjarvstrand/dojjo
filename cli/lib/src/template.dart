import 'package:jinja/jinja.dart';
import 'package:path/path.dart' as p;

final _environment = Environment(
  filters: {
    'sanitize': (String value) => sanitize(value),
    'sanitize_db': (String value) => sanitizeDb(value),
    'hash_port': (String value) => hashPort(value).toString(),
  },
);

String renderTemplate(
  String template, {
  required String name,
  required String repoPath,
  int? workspaceIndex,
}) =>
    _environment.fromString(template).render({
      'name': name,
      'branch': name,
      'repo_path': repoPath,
      'repo': p.basename(repoPath),
      'workspace_index': workspaceIndex ?? -1,
    });

/// Filesystem-safe name: replace path separators with hyphens.
String sanitize(String value) => value.replaceAll(RegExp(r'[/\\]'), '-');

/// Database-safe name: lowercase, non-alphanumeric to underscores, short hash suffix.
String sanitizeDb(String value) {
  final base = value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '_');
  final hash = hashPort(value).toRadixString(36).substring(0, 3);
  return '${base}_$hash';
}

/// Deterministic port in range 10000-19999 based on string hash.
int hashPort(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return 10000 + hash % 10000;
}
