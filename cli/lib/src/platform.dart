import 'dart:io';

import 'package:dojjo/src/util/extensions.dart';

/// A [ProcessResult] with typed [stdout] and [stderr] fields.
class ShellResult {
  ShellResult(ProcessResult result)
    : exitCode = result.exitCode,
      stdout = (result.stdout as String).trim().nonEmptyOrNull,
      stderr = (result.stderr as String).trim().nonEmptyOrNull;

  final int exitCode;
  final String? stdout;
  final String? stderr;
}

/// Returns the user's home directory, cross-platform.
String get homeDirectory {
  final env = Platform.environment;
  if (Platform.isWindows) {
    final userProfile = env['USERPROFILE'];
    if (userProfile != null) return userProfile;

    final homeDrive = env['HOMEDRIVE'];
    final homePath = env['HOMEPATH'];
    if (homeDrive != null && homePath != null) return homeDrive + homePath;

    throw StateError(
      'Could not determine home directory. '
      'Neither USERPROFILE nor HOMEDRIVE/HOMEPATH are set.',
    );
  }

  final home = env['HOME'];
  if (home != null) return home;

  throw StateError('Could not determine home directory. HOME is not set.');
}

/// Runs an executable and returns a typed [ShellResult].
Future<ShellResult> runProcess(String executable, List<String> args, {String? workingDirectory}) =>
    Process.run(executable, args, workingDirectory: workingDirectory).then(ShellResult.new);

/// Runs a shell command cross-platform.
/// Uses `sh -c` on Unix and `cmd /c` on Windows.
Future<ShellResult> runShellCommand(String command, {String? workingDirectory}) {
  final (shell, args) = Platform.isWindows ? ('cmd', ['/c', command]) : ('sh', ['-c', command]);
  return runProcess(shell, args, workingDirectory: workingDirectory);
}
