import 'dart:async';
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
/// Follows worktrunk's execution model:
/// - Pre-hooks: blocking, sequential steps, parallel commands within each step.
///   Aborts on first failure.
/// - Post-hooks: run in the background. Steps are sequential, commands within
///   each step are parallel. Errors are logged but don't abort.
Future<void> runHooks(
  String hookType, {
  required HookMap hooks,
  required String name,
  required String path,
  int? workspaceIndex,
  String? target,
}) async {
  final pipeline = hooks[hookType];
  if (pipeline == null || pipeline.isEmpty) return;

  final isBlocking = hookType.startsWith('pre-');

  final context = await buildFullContext(
    name: name,
    path: path,
    workspaceIndex: workspaceIndex,
    hookType: hookType,
    target: target,
  );

  if (isBlocking) {
    await _runPipeline(pipeline, context, path, blocking: true);
  } else {
    // Post-hooks run in the background — don't await.
    unawaited(_runPipeline(pipeline, context, path, blocking: false));
  }
}

Future<void> _runPipeline(
  HookPipeline pipeline,
  Map<String, Object?> context,
  String workingDirectory, {
  required bool blocking,
}) async {
  for (final step in pipeline) {
    if (step.length == 1) {
      // Single command — run directly.
      await _runEntry(step.first, context, workingDirectory, blocking: blocking);
    } else {
      // Multiple commands — run in parallel, wait for all.
      final futures = step.map((entry) => _runEntry(entry, context, workingDirectory, blocking: blocking));
      await Future.wait(futures);
    }
  }
}

Future<void> _runEntry(
  HookEntry entry,
  Map<String, Object?> context,
  String workingDirectory, {
  required bool blocking,
}) async {
  final entryContext = {...context, 'hook_name': entry.name};
  final rendered = rewriteWorktrunkCommands(render(entry.command, entryContext));
  final hookType = context['hook_type'] ?? '';

  stderr.writeln('hook($hookType/${entry.name}): $rendered');

  final result = await runShellCommand(rendered, workingDirectory: workingDirectory);

  final output = (result.stdout as String).trim();
  if (output.isNotEmpty) {
    stderr.writeln(output);
  }

  final error = (result.stderr as String).trim();
  if (error.isNotEmpty) {
    stderr.writeln(error);
  }

  if (result.exitCode != 0) {
    if (blocking) {
      throw Exception(
        'Hook $hookType/${entry.name} failed with exit code ${result.exitCode}',
      );
    }
    stderr.writeln(
      'hook($hookType/${entry.name}) failed (exit ${result.exitCode}), continuing',
    );
  }
}
