import 'dart:io';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/template.dart';

final _wtStepPattern = RegExp(r'\bwt\s+step\s+');
final _wtPattern = RegExp(r'\bwt\s+');

/// Rewrite worktrunk commands to djo equivalents.
/// `wt step copy-ignored ...` → `djo copy-ignored ...`
/// `wt merge ...` → `djo merge ...`
String rewriteWorktrunkCommands(String command) =>
    command.replaceAll(_wtStepPattern, 'djo ').replaceAll(_wtPattern, 'djo ');

/// Run all hooks for a given type.
///
/// Pre-hooks (those starting with "pre-") are blocking: if any hook fails,
/// execution stops and an exception is thrown.
///
/// Post-hooks run sequentially but don't abort on failure — errors are
/// logged to stderr.
Future<void> runHooks(
  String hookType, {
  required HookMap hooks,
  required String name,
  required String path,
  int? workspaceIndex,
  String? target,
}) async {
  final entries = hooks[hookType];
  if (entries == null || entries.isEmpty) return;

  final isBlocking = hookType.startsWith('pre-');

  final context = await buildFullContext(
    name: name,
    path: path,
    workspaceIndex: workspaceIndex,
    hookType: hookType,
    target: target,
  );

  for (final entry in entries) {
    context['hook_name'] = entry.name;
    final rendered = rewriteWorktrunkCommands(render(entry.command, context));

    stderr.writeln('hook($hookType/${entry.name}): $rendered');

    final result = await runShellCommand(rendered, workingDirectory: path);

    final output = (result.stdout as String).trim();
    if (output.isNotEmpty) {
      stderr.writeln(output);
    }

    final error = (result.stderr as String).trim();
    if (error.isNotEmpty) {
      stderr.writeln(error);
    }

    if (result.exitCode != 0) {
      if (isBlocking) {
        throw Exception(
          'Hook $hookType/${entry.name} failed with exit code '
          '${result.exitCode}',
        );
      }
      stderr.writeln(
        'hook($hookType/${entry.name}) failed '
        '(exit ${result.exitCode}), continuing',
      );
    }
  }
}
