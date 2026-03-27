import 'dart:io';

import 'package:dojjo/src/config.dart';
import 'package:dojjo/src/hooks.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dojjo_hooks_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('hook execution', () {
    test('single command runs', () async {
      final outFile = File('${tempDir.path}/out.txt');
      final hooks = <String, HookPipeline>{
        'pre-merge': [
          [HookEntry(name: 'write', command: 'echo hello > ${outFile.path}')],
        ],
      };
      await runHooks('pre-merge', hooks: hooks, name: 'ws', path: tempDir.path);
      expect(outFile.readAsStringSync().trim(), equals('hello'));
    });

    test('sequential steps run in order', () async {
      final outFile = File('${tempDir.path}/order.txt');
      final hooks = <String, HookPipeline>{
        'pre-merge': [
          [HookEntry(name: 'first', command: 'echo first >> ${outFile.path}')],
          [HookEntry(name: 'second', command: 'echo second >> ${outFile.path}')],
        ],
      };
      await runHooks('pre-merge', hooks: hooks, name: 'ws', path: tempDir.path);
      final lines = outFile.readAsStringSync().trim().split('\n');
      expect(lines, equals(['first', 'second']));
    });

    test('parallel commands within a step all execute', () async {
      final outA = File('${tempDir.path}/a.txt');
      final outB = File('${tempDir.path}/b.txt');
      final hooks = <String, HookPipeline>{
        'pre-merge': [
          [
            HookEntry(name: 'a', command: 'echo a > ${outA.path}'),
            HookEntry(name: 'b', command: 'echo b > ${outB.path}'),
          ],
        ],
      };
      await runHooks('pre-merge', hooks: hooks, name: 'ws', path: tempDir.path);
      expect(outA.readAsStringSync().trim(), equals('a'));
      expect(outB.readAsStringSync().trim(), equals('b'));
    });

    test('pre-hook failure aborts pipeline', () async {
      final outFile = File('${tempDir.path}/after.txt');
      final hooks = <String, HookPipeline>{
        'pre-merge': [
          [HookEntry(name: 'fail', command: 'exit 1')],
          [HookEntry(name: 'after', command: 'echo ran > ${outFile.path}')],
        ],
      };
      await expectLater(
        runHooks('pre-merge', hooks: hooks, name: 'ws', path: tempDir.path),
        throwsA(isA<Exception>()),
      );
      // Second step should not have run.
      expect(outFile.existsSync(), isFalse);
    });

    test('post-hook failure does not throw', () async {
      final hooks = <String, HookPipeline>{
        'post-merge': [
          [HookEntry(name: 'fail', command: 'exit 1')],
        ],
      };
      // Should not throw — post-hooks run in background.
      await runHooks('post-merge', hooks: hooks, name: 'ws', path: tempDir.path);
      // Give background hook time to complete.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });

    test('pipeline: step 2 runs after step 1 completes', () async {
      final outFile = File('${tempDir.path}/pipeline.txt');
      final hooks = <String, HookPipeline>{
        'pre-merge': [
          [HookEntry(name: 'create', command: 'echo step1 > ${outFile.path}')],
          [HookEntry(name: 'append', command: 'echo step2 >> ${outFile.path}')],
          [
            HookEntry(name: 'par-a', command: 'echo par-a >> ${outFile.path}'),
            HookEntry(name: 'par-b', command: 'echo par-b >> ${outFile.path}'),
          ],
        ],
      };
      await runHooks('pre-merge', hooks: hooks, name: 'ws', path: tempDir.path);
      final lines = outFile.readAsStringSync().trim().split('\n');
      // First two lines must be in order. Last two can be either order.
      expect(lines[0], equals('step1'));
      expect(lines[1], equals('step2'));
      expect(lines.length, equals(4));
      expect(lines.sublist(2).toSet(), equals({'par-a', 'par-b'}));
    });
  });
}
