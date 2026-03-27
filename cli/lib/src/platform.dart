import 'dart:io';

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

/// Runs a shell command cross-platform.
/// Uses `sh -c` on Unix and `cmd /c` on Windows.
Future<ProcessResult> runShellCommand(
  String command, {
  String? workingDirectory,
}) {
  if (Platform.isWindows) {
    return Process.run('cmd', ['/c', command], workingDirectory: workingDirectory);
  }
  return Process.run('sh', ['-c', command], workingDirectory: workingDirectory);
}
