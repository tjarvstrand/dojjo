import 'dart:io';

import 'package:dojjo/src/state.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String wrapperPath;
  late String primaryPath;

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

  group('sharedJjDir', () {
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
}
