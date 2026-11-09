import 'dart:io';

import 'package:dojjo/src/state.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Whether a `jj` binary is available, so the integration test can be skipped
bool _jjAvailable() {
  try {
    return Process.runSync('jj', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<void> _runJj(List<String> arguments, String workingDirectory) async {
  final result = await Process.run('jj', arguments, workingDirectory: workingDirectory);
  expect(result.exitCode, equals(0), reason: 'jj ${arguments.join(' ')} failed: ${result.stderr}');
}

void main() {
  late Directory tempDir;
  late String wrapperPath;
  late String primaryPath;

  group('sharedJjDir', () {
    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dojjo_state_test_');
      wrapperPath = p.join(tempDir.path, 'wrapper');
      primaryPath = p.join(wrapperPath, 'primary');
      Directory(p.join(primaryPath, '.jj', 'repo')).createSync(recursive: true);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    /// Creates a secondary workspace beside [primaryPath] whose `.jj/repo` file
    /// holds [repoPointer], the way jj writes it (relative to the workspace's
    /// own `.jj` dir, or absolute).
    String createSecondaryWorkspace(String name, String repoPointer) {
      final workspacePath = p.join(wrapperPath, name);
      final jjDir = Directory(p.join(workspacePath, '.jj'))..createSync(recursive: true);
      File(p.join(jjDir.path, 'repo')).writeAsStringSync(repoPointer);
      return workspacePath;
    }

    test('returns the .jj dir of a primary workspace', () {
      expect(sharedJjDir(primaryPath), equals(p.join(primaryPath, '.jj')));
    });

    test('returns the .jj dir when the workspace has no repo pointer', () {
      final workspacePath = p.join(wrapperPath, 'plain');
      Directory(workspacePath).createSync(recursive: true);
      expect(sharedJjDir(workspacePath), equals(p.join(workspacePath, '.jj')));
    });

    test('ignores an empty repo pointer', () {
      final workspacePath = createSecondaryWorkspace('empty', '\n');
      expect(sharedJjDir(workspacePath), equals(p.join(workspacePath, '.jj')));
    });

    test('resolves the relative repo pointer of a secondary workspace against that workspace', () {
      final workspacePath = createSecondaryWorkspace('feat-x', '../../primary/.jj/repo');
      expect(sharedJjDir(workspacePath), equals(p.join(primaryPath, '.jj')));
    });

    test('resolves the repo pointer independently of the current working directory', () {
      final workspacePath = createSecondaryWorkspace('feat-x', '../../primary/.jj/repo');
      final originalWorkingDirectory = Directory.current.path;
      addTearDown(() => Directory.current = originalWorkingDirectory);

      Directory.current = workspacePath;

      final jjDir = sharedJjDir(workspacePath);
      expect(jjDir, equals(p.join(primaryPath, '.jj')));
      expect(p.isAbsolute(jjDir), isTrue);
      expect(jjDir, isNot(contains('..')));
    });

    test('accepts an absolute repo pointer', () {
      final workspacePath = createSecondaryWorkspace('feat-x', p.join(primaryPath, '.jj', 'repo'));
      expect(sharedJjDir(workspacePath), equals(p.join(primaryPath, '.jj')));
    });

    test('state and log paths of a secondary workspace stay inside the primary repo', () {
      final workspacePath = createSecondaryWorkspace('feat-x', '../../primary/.jj/repo');

      final jjDir = sharedJjDir(workspacePath);

      expect(p.join(jjDir, 'djo-state'), equals(p.join(primaryPath, '.jj', 'djo-state')));
      expect(p.join(jjDir, 'djo', 'logs'), equals(p.join(primaryPath, '.jj', 'djo', 'logs')));
    });
  });

  group('secondary workspace from a real jj repository', () {
    test('state and log files land in the primary workspace .jj dir', () async {
      final repoRoot = Directory.systemTemp.createTempSync('dojjo_state_jj_test_');
      final originalWorkingDirectory = Directory.current.path;
      addTearDown(() {
        Directory.current = originalWorkingDirectory;
        repoRoot.deleteSync(recursive: true);
      });

      final wrapper = p.join(repoRoot.path, 'wrapper');
      final primary = p.join(wrapper, 'primary');
      final secondary = p.join(wrapper, 'feat-x');
      Directory(primary).createSync(recursive: true);
      await _runJj(['git', 'init', '--no-colocate'], primary);
      await _runJj(['workspace', 'add', secondary], primary);
      expect(File(p.join(secondary, '.jj', 'repo')).readAsStringSync().trim(), equals('../../primary/.jj/repo'));

      // The defect only shows up when resolving from a secondary workspace, so
      // run the commands the way djo does: with that workspace as the cwd.
      Directory.current = secondary;

      await savePreviousWorkspace('default');

      // jj reports canonical paths, which differ from the temp dir path when
      // the system temp dir sits behind a symlink (/var -> /private/var on macOS).
      final canonicalPrimary = Directory(primary).resolveSymbolicLinksSync();
      final stateFile = File(p.join(canonicalPrimary, '.jj', 'djo-state'));
      expect(stateFile.existsSync(), isTrue);
      expect(stateFile.readAsStringSync().trim(), equals('default'));
      expect(await loadPreviousWorkspace(), equals('default'));
      expect(await logsDir(), equals(p.join(canonicalPrimary, '.jj', 'djo', 'logs')));
      expect(await primaryWorkspaceRoot(), equals(canonicalPrimary));
    }, skip: _jjAvailable() ? false : 'jj is not installed');
  });
}
