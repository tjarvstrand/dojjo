import 'package:path/path.dart' as p;

final _pattern = RegExp(r'\{\{\s*(.+?)\s*\}\}');

String renderTemplate(
  String template, {
  required String name,
  required String repoPath,
}) {
  final repo = p.basename(repoPath);

  return template.replaceAllMapped(_pattern, (match) {
    final expr = match.group(1)!.trim();

    // Check for filter syntax: "var | filter"
    final pipeIndex = expr.indexOf('|');
    if (pipeIndex != -1) {
      final varName = expr.substring(0, pipeIndex).trim();
      final filter = expr.substring(pipeIndex + 1).trim();
      final value = _resolveVar(varName, name: name, repoPath: repoPath, repo: repo);
      return _applyFilter(value, filter);
    }

    return _resolveVar(expr, name: name, repoPath: repoPath, repo: repo);
  });
}

String _resolveVar(
  String varName, {
  required String name,
  required String repoPath,
  required String repo,
}) =>
    switch (varName) {
      'name' || 'branch' => name,
      'repo_path' => repoPath,
      'repo' => repo,
      _ => '{{ $varName }}', // pass through unknown vars
    };

String _applyFilter(String value, String filter) => switch (filter) {
      'sanitize' => sanitize(value),
      'hash_port' => hashPort(value).toString(),
      _ => value, // pass through unknown filters
    };

/// Filesystem-safe name: replace slashes with hyphens.
String sanitize(String value) => value.replaceAll('/', '-');

/// Deterministic port in range 10000–19999 based on string hash.
int hashPort(String value) {
  var hash = 0;
  for (final c in value.codeUnits) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  return 10000 + hash % 10000;
}
