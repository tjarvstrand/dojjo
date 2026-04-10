import 'dart:async';
import 'dart:io';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/platform.dart';
import 'package:dojjo/src/state.dart';
import 'package:dojjo/src/template.dart';
import 'package:dojjo/src/util/extensions.dart';
import 'package:path/path.dart' as p;

final _wtStepPattern = RegExp(r'\bwt\s+step\s+');
final _wtPattern = RegExp(r'\bwt\s+');

/// Rewrite worktrunk commands to djo equivalents.
/// `wt step <alias> ...` → `djo run <alias> ...`
/// `wt merge ...` → `djo merge ...`
String rewriteWorktrunkCommands(String command) =>
    command.replaceAll(_wtStepPattern, 'djo run ').replaceAll(_wtPattern, 'djo ');

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
  String? target,
}) async {
  final pipeline = hooks[hookType];
  if (pipeline == null || pipeline.isEmpty) return;

  final isBlocking = hookType.startsWith('pre-');

  final context = await buildFullContext(name: name, path: path, hookType: hookType, target: target);

  if (isBlocking) {
    await _runPipeline(pipeline, context, path, blocking: true, label: hookType);
  } else {
    // Post-hooks run in the background — don't await.
    unawaited(_runPipeline(pipeline, context, path, blocking: false, label: hookType));
  }
}

/// Run an alias pipeline (always blocking, aborts on failure).
Future<void> runAlias(
  String alias, {
  required HookPipeline pipeline,
  required String name,
  required String path,
}) async {
  final context = await buildFullContext(name: name, path: path);
  await _runPipeline(pipeline, context, path, blocking: true, label: alias);
}

Future<void> _runPipeline(
  HookPipeline pipeline,
  Map<String, Object?> context,
  String workingDirectory, {
  required bool blocking,
  required String label,
}) async {
  final run = blocking ? _runBlocking : _runInBackground;
  for (final step in pipeline) {
    // Run individual hook entries in parallel
    await Future.wait([
      for (final entry in step)
        run(
          entry,
          rewriteWorktrunkCommands(render(entry.command, {...context, 'hook_name': entry.name})),
          workingDirectory,
          label,
        ),
    ]);
  }
}

Future<void> _runBlocking(HookEntry entry, String command, String workingDirectory, String label) async {
  stderr.writeln('$label(${entry.name}): $command');
  final exitCode = await runShellCommandToSink(command, sink: stderr, workingDirectory: workingDirectory);
  if (exitCode != 0) {
    throw Exception('$label/${entry.name} failed with exit code $exitCode');
  }
}

/// Sanitize a string for use in a filename.
String _sanitizeForFilename(String input) => input.replaceAll(RegExp(r'[^\w\-.]'), '-');

Future<void> _runInBackground(HookEntry entry, String command, String workingDirectory, String label) async {
  final logPath = p.join(await logsDir(), '${_sanitizeForFilename(label)}-${_sanitizeForFilename(entry.name)}.log');
  final logFile = File(logPath)..parent.createSync(recursive: true);
  final sink = logFile.openWrite(mode: FileMode.append);
  try {
    sink.writeln('$label(${entry.name}): $command');
    final exitCode = await runShellCommandToSink(command, sink: sink, workingDirectory: workingDirectory);
    if (exitCode != 0) {
      stderr.writeln('$label(${entry.name}) failed (exit $exitCode), see $logPath');
    }
  } finally {
    await sink.flush().ignoreErrors();
    await sink.close();
  }
}
