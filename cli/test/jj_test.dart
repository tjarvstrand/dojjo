import 'package:dojjo/src/jj.dart';
import 'package:test/test.dart';

void main() {
  final defaultWs = WorkspaceInfo(
    name: 'default',
    changeId: 'uprnywsvpzrk',
    bookmarks: '',
    description: 'Use zio-logging',
    conflict: false,
    divergent: false,
    empty: false,
    current: true,
    modifiedFiles: 3,
  );

  group('parseWorkspaceList', () {
    test('parses single workspace line', () {
      const input = 'default\tuprnywsvpzrk\t\tUse zio-logging\tfalse\tfalse\tfalse\ttrue\t3';
      expect(parseWorkspaceList(input), equals([defaultWs]));
    });

    test('parses multiple workspaces', () {
      const input =
          'default\tuprnywsvpzrk\t\tUse zio-logging\tfalse\tfalse\tfalse\ttrue\t3\n'
          'feature\tabcdef123456\tmain\tAdd feature\ttrue\tfalse\tfalse\tfalse\t7';
      final result = parseWorkspaceList(input);
      expect(result, hasLength(2));
      expect(result[0].name, equals('default'));
      expect(result[1].name, equals('feature'));
      expect(result[1].bookmarks, equals('main'));
      expect(result[1].conflict, isTrue);
      expect(result[1].current, isFalse);
      expect(result[1].modifiedFiles, equals(7));
    });

    test('parses empty output', () {
      expect(parseWorkspaceList(''), isEmpty);
    });

    test('skips blank lines', () {
      const input = '\ndefault\tuprnywsvpzrk\t\tUse zio-logging\tfalse\tfalse\tfalse\ttrue\t3\n\n';
      expect(parseWorkspaceList(input), hasLength(1));
    });

    test('parses empty bookmarks field', () {
      const input = 'ws\tid\t\tdesc\tfalse\tfalse\tfalse\ttrue\t0';
      expect(parseWorkspaceList(input).first.bookmarks, isEmpty);
    });

    test('parses multiple bookmarks', () {
      const input = 'ws\tid\tmain,feature\tdesc\tfalse\tfalse\tfalse\ttrue\t0';
      expect(parseWorkspaceList(input).first.bookmarks, equals('main,feature'));
    });

    test('parses empty description', () {
      const input = 'ws\tid\t\t\tfalse\tfalse\tfalse\ttrue\t0';
      expect(parseWorkspaceList(input).first.description, isEmpty);
    });

    test('handles non-numeric modified files', () {
      const input = 'ws\tid\t\tdesc\tfalse\tfalse\tfalse\ttrue\tbad';
      expect(parseWorkspaceList(input).first.modifiedFiles, equals(0));
    });

    test('parses all boolean flags correctly', () {
      const input = 'ws\tid\t\tdesc\ttrue\ttrue\ttrue\tfalse\t0';
      final ws = parseWorkspaceList(input).first;
      expect(ws.conflict, isTrue);
      expect(ws.divergent, isTrue);
      expect(ws.empty, isTrue);
      expect(ws.current, isFalse);
    });

    test('throws FormatException on too few fields', () {
      const input = 'ws\tid\tbookmarks';
      expect(() => parseWorkspaceList(input), throwsFormatException);
    });

    test('throws FormatException on too many fields', () {
      const input = 'ws\tid\t\tdesc\tfalse\tfalse\tfalse\ttrue\t0\textra';
      expect(() => parseWorkspaceList(input), throwsFormatException);
    });
  });
}
