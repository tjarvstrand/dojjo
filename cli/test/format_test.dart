import 'dart:convert';

import 'package:dojjo/src/format.dart';
import 'package:dojjo/src/jj.dart';
import 'package:test/test.dart';

WorkspaceInfo ws({
  String name = 'default',
  String changeId = 'abc123',
  List<String> bookmarks = const [],
  String description = '',
  bool conflict = false,
  bool divergent = false,
  bool empty = false,
  bool current = false,
  int modifiedFiles = 0,
  String age = '',
  String path = '',
  int insertions = 0,
  int deletions = 0,
}) => WorkspaceInfo(
  name: name,
  changeId: changeId,
  bookmarks: bookmarks,
  description: description,
  conflict: conflict,
  divergent: divergent,
  empty: empty,
  current: current,
  modifiedFiles: modifiedFiles,
  age: age,
  path: path,
  insertions: insertions,
  deletions: deletions,
);

void main() {
  group('formatWorkspace', () {
    test('current workspace gets * marker', () {
      expect(formatWorkspace(ws(current: true)), startsWith('* '));
    });

    test('non-current workspace gets space marker', () {
      expect(formatWorkspace(ws()), startsWith('  '));
    });

    test('shows bookmark in brackets', () {
      expect(formatWorkspace(ws(bookmarks: ['main'])), contains('[main]'));
    });

    test('omits bracket when no bookmarks', () {
      expect(formatWorkspace(ws()), isNot(contains('[')));
    });

    test('shows conflict symbol', () {
      expect(formatWorkspace(ws(conflict: true)), contains('\u2718'));
    });

    test('shows divergent symbol', () {
      expect(formatWorkspace(ws(divergent: true)), contains('\u2195'));
    });

    test('shows both conflict and divergent symbols', () {
      final result = formatWorkspace(ws(conflict: true, divergent: true));
      expect(result, contains('\u2718'));
      expect(result, contains('\u2195'));
    });

    test('no flags when clean', () {
      final result = formatWorkspace(ws());
      expect(result, isNot(contains('\u2718')));
      expect(result, isNot(contains('\u2195')));
    });

    test('shows file count when not empty', () {
      expect(formatWorkspace(ws(modifiedFiles: 5)), contains('(5 files)'));
    });

    test('omits file count when empty', () {
      expect(formatWorkspace(ws(empty: true)), isNot(contains('files')));
    });

    test('shows description', () {
      expect(formatWorkspace(ws(description: 'Add feature')), contains('Add feature'));
    });

    test('full format example', () {
      expect(
        formatWorkspace(
          ws(
            name: 'feature',
            current: true,
            bookmarks: ['feat-branch'],
            conflict: true,
            description: 'WIP',
            modifiedFiles: 3,
          ),
        ),
        equals('* feature [feat-branch] \u2718 WIP (3 files)'),
      );
    });
  });

  group('workspaceListJson', () {
    test('produces valid JSON array', () {
      final json = workspaceListJson([ws(name: 'a'), ws(name: 'b')]);
      final parsed = jsonDecode(json) as List<Object?>;
      expect(parsed, hasLength(2));
    });

    test('includes all fields', () {
      final json = workspaceListJson([
        ws(
          name: 'ws',
          changeId: 'id',
          bookmarks: ['bm'],
          description: 'desc',
          conflict: true,
          divergent: true,
          empty: true,
          current: true,
          modifiedFiles: 42,
        ),
      ]);
      final parsed = (jsonDecode(json) as List<Object?>).first! as Map<String, Object?>;
      expect(parsed['name'], equals('ws'));
      expect(parsed['changeId'], equals('id'));
      expect(parsed['bookmarks'], equals(['bm']));
      expect(parsed['description'], equals('desc'));
      expect(parsed['conflict'], isTrue);
      expect(parsed['divergent'], isTrue);
      expect(parsed['empty'], isTrue);
      expect(parsed['current'], isTrue);
      expect(parsed['modifiedFiles'], equals(42));
    });

    test('empty list produces empty array', () {
      expect(workspaceListJson([]), equals('[]'));
    });

    test('escapes special characters in description', () {
      final json = workspaceListJson([ws(description: 'say "hello"')]);
      // Should be valid JSON
      final parsed = (jsonDecode(json) as List<Object?>).first! as Map<String, Object?>;
      expect(parsed['description'], equals('say "hello"'));
    });
  });

  group('formatWorkspaceTable', () {
    test('returns empty string for empty list', () {
      expect(formatWorkspaceTable([]), isEmpty);
    });

    test('includes header row', () {
      final output = formatWorkspaceTable([ws()]);
      final lines = output.split('\n');
      expect(lines.first, contains('Name'));
      expect(lines.first, contains('Revision'));
      expect(lines.first, contains('Age'));
      expect(lines.first, contains('Path'));
    });

    test('shows current workspace marker', () {
      final output = formatWorkspaceTable([ws(current: true)]);
      final dataLine = output.split('\n')[1];
      expect(dataLine, startsWith('*'));
    });

    test('shows diff stats', () {
      final output = formatWorkspaceTable([ws(insertions: 10, deletions: 3)]);
      expect(output, contains('+10 -3'));
    });

    test('omits diff stats for empty workspace with no changes', () {
      final output = formatWorkspaceTable([ws(empty: true)]);
      final dataLine = output.split('\n')[1];
      expect(dataLine, isNot(contains('+0')));
    });

    test('shows age', () {
      final output = formatWorkspaceTable([ws(age: '2 hours ago')]);
      expect(output, contains('2 hours ago'));
    });

    test('shows path', () {
      final output = formatWorkspaceTable([ws(path: '/home/user/repo')]);
      expect(output, contains('/home/user/repo'));
    });

    test('aligns columns across rows', () {
      final output = formatWorkspaceTable([
        ws(name: 'short', changeId: 'abc'),
        ws(name: 'much-longer-name', changeId: 'xyz'),
      ]);
      final lines = output.split('\n');
      // Header and both data rows should have Revision column at the same position.
      final headerCommitPos = lines[0].indexOf('Revision');
      final row1CommitStart = lines[1].indexOf('abc');
      final row2CommitStart = lines[2].indexOf('xyz');
      expect(row1CommitStart, equals(row2CommitStart));
      expect(row1CommitStart, equals(headerCommitPos));
    });
  });
}
