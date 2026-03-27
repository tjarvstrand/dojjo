import 'dart:convert';
import 'dart:io';

import 'package:dojjo/src/jj.dart' as jj;
import 'package:jinja/jinja.dart';
import 'package:path/path.dart' as p;

final _environment = Environment(
  filters: {
    'sanitize': (String value) => sanitize(value),
    'sanitize_db': (String value) => sanitizeDb(value),
    'hash_port': (String value) => hashPort(value).toString(),
  },
);

/// Render a template with the given context variables.
String render(String template, Map<String, Object?> context) =>
    _environment.fromString(template).render(context);

/// Render a template with standard workspace variables.
/// For simple contexts (worktree-path, aliases) where async jj calls aren't needed.
String renderTemplate(
  String template, {
  required String name,
  required String repoPath,
  int? workspaceIndex,
}) =>
    render(template, {
      'name': name,
      'branch': name,
      'repo_path': repoPath,
      'repo': p.basename(repoPath),
      'worktree_path': repoPath,
      'workspace_path': repoPath,
      'worktree_name': p.basename(repoPath),
      'workspace_name': p.basename(repoPath),
      'cwd': Directory.current.path,
      'workspace_index': workspaceIndex ?? -1,
    });

/// Build a full template context with all worktrunk-compatible variables.
/// Requires async jj calls for commit, remote, and default branch info.
Future<Map<String, Object?>> buildFullContext({
  required String name,
  required String path,
  int? workspaceIndex,
  String? hookType,
  String? hookName,
  String? target,
}) async {
  final context = <String, Object?>{
    'name': name,
    'branch': name,
    'repo_path': path,
    'repo': p.basename(path),
    'worktree_path': path,
    'workspace_path': path,
    'worktree_name': p.basename(path),
    'workspace_name': p.basename(path),
    'cwd': Directory.current.path,
    'workspace_index': workspaceIndex ?? -1,
    'hook_type': hookType ?? '',
    'hook_name': hookName ?? '',
  };

  // Commit info.
  try {
    final commitId = await jj.logTemplate('@', 'commit_id');
    context['commit'] = commitId;
    context['short_commit'] = commitId.length >= 7 ? commitId.substring(0, 7) : commitId;
  } on jj.CommandError {
    context['commit'] = '';
    context['short_commit'] = '';
  }

  // Remote info.
  try {
    final remoteOutput = await jj.gitRemoteList();
    final lines = const LineSplitter().convert(remoteOutput).where((l) => l.isNotEmpty);
    if (lines.isNotEmpty) {
      final parts = lines.first.split(RegExp(r'\s+'));
      context['remote'] = parts.first;
      if (parts.length > 1) {
        context['remote_url'] = parts[1];
      }
    }
  } on jj.CommandError {
    // No remotes.
  }

  // Default branch / primary worktree.
  try {
    final defaultBranch = await jj.logTemplate('trunk()', 'bookmarks');
    context['default_branch'] = defaultBranch;
    context['base'] = defaultBranch;
  } on jj.CommandError {
    // No trunk.
  }

  // Primary (default) workspace/worktree path.
  try {
    final primaryPath = await jj.workspaceRoot('default');
    context['primary_worktree_path'] = primaryPath;
    context['primary_workspace_path'] = primaryPath;
  } on jj.CommandError {
    try {
      final primaryPath = await jj.workspaceRoot();
      context['primary_worktree_path'] = primaryPath;
      context['primary_workspace_path'] = primaryPath;
    } on jj.CommandError {
      // Can't determine primary workspace.
    }
  }

  // Base worktree/workspace path (same as primary).
  if (context.containsKey('primary_worktree_path')) {
    context['base_worktree_path'] = context['primary_worktree_path'];
    context['base_workspace_path'] = context['primary_worktree_path'];
  }

  // Upstream.
  try {
    final remote = context['remote'] as String?;
    if (remote != null) {
      context['upstream'] = '$name@$remote';
    }
  } on Exception {
    // No upstream.
  }

  // Target (merge target, if provided).
  if (target != null) {
    context['target'] = target;
    try {
      final targetPath = await jj.workspaceRoot(target);
      context['target_worktree_path'] = targetPath;
      context['target_workspace_path'] = targetPath;
    } on jj.CommandError {
      // Target workspace may not exist.
    }
  }

  return context;
}

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
