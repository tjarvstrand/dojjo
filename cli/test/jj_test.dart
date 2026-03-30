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
    age: '2 hours ago',
  );

  group('parseWorkspaceList', () {
    test('parses single workspace line', () {
      const input = 'default\tuprnywsvpzrk\t\tUse zio-logging\tfalse\tfalse\tfalse\ttrue\t3\t2 hours ago';
      expect(parseWorkspaceList(input), equals([defaultWs]));
    });

    test('parses multiple workspaces', () {
      const input =
          'default\tuprnywsvpzrk\t\tUse zio-logging\tfalse\tfalse\tfalse\ttrue\t3\t2 hours ago\n'
          'feature\tabcdef123456\tmain\tAdd feature\ttrue\tfalse\tfalse\tfalse\t7\t1 day ago';
      final result = parseWorkspaceList(input);
      expect(result, hasLength(2));
      expect(result[0].name, equals('default'));
      expect(result[1].name, equals('feature'));
      expect(result[1].bookmarks, equals('main'));
      expect(result[1].conflict, isTrue);
      expect(result[1].current, isFalse);
      expect(result[1].modifiedFiles, equals(7));
      expect(result[1].age, equals('1 day ago'));
    });

    test('parses empty output', () {
      expect(parseWorkspaceList(''), isEmpty);
    });

    test('skips blank lines', () {
      const input = '\ndefault\tuprnywsvpzrk\t\tUse zio-logging\tfalse\tfalse\tfalse\ttrue\t3\t2 hours ago\n\n';
      expect(parseWorkspaceList(input), hasLength(1));
    });

    test('parses empty bookmarks field', () {
      const input = 'ws\tid\t\tdesc\tfalse\tfalse\tfalse\ttrue\t0\t5 minutes ago';
      expect(parseWorkspaceList(input).first.bookmarks, isEmpty);
    });

    test('parses multiple bookmarks', () {
      const input = 'ws\tid\tmain,feature\tdesc\tfalse\tfalse\tfalse\ttrue\t0\t5 minutes ago';
      expect(parseWorkspaceList(input).first.bookmarks, equals('main,feature'));
    });

    test('parses empty description', () {
      const input = 'ws\tid\t\t\tfalse\tfalse\tfalse\ttrue\t0\t5 minutes ago';
      expect(parseWorkspaceList(input).first.description, isEmpty);
    });

    test('handles non-numeric modified files', () {
      const input = 'ws\tid\t\tdesc\tfalse\tfalse\tfalse\ttrue\tbad\t5 minutes ago';
      expect(parseWorkspaceList(input).first.modifiedFiles, equals(0));
    });

    test('parses all boolean flags correctly', () {
      const input = 'ws\tid\t\tdesc\ttrue\ttrue\ttrue\tfalse\t0\t5 minutes ago';
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
      const input = 'ws\tid\t\tdesc\tfalse\tfalse\tfalse\ttrue\t0\t5 minutes ago\textra';
      expect(() => parseWorkspaceList(input), throwsFormatException);
    });
  });

  group('parseDiffStatSummary', () {
    test('parses full summary', () {
      final result = parseDiffStatSummary('8 files changed, 148 insertions(+), 36 deletions(-)');
      expect(result.insertions, equals(148));
      expect(result.deletions, equals(36));
    });

    test('parses insertions only', () {
      final result = parseDiffStatSummary('1 file changed, 5 insertions(+)');
      expect(result.insertions, equals(5));
      expect(result.deletions, equals(0));
    });

    test('parses deletions only', () {
      final result = parseDiffStatSummary('2 files changed, 10 deletions(-)');
      expect(result.insertions, equals(0));
      expect(result.deletions, equals(10));
    });

    test('parses singular forms', () {
      final result = parseDiffStatSummary('1 file changed, 1 insertion(+), 1 deletion(-)');
      expect(result.insertions, equals(1));
      expect(result.deletions, equals(1));
    });

    test('returns zeros for unrecognized input', () {
      final result = parseDiffStatSummary('no changes');
      expect(result.insertions, equals(0));
      expect(result.deletions, equals(0));
    });
  });
}
