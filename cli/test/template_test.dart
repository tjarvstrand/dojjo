import 'package:dojjo/src/template.dart';
import 'package:test/test.dart';

void main() {
  group('renderTemplate', () {
    test('substitutes name', () {
      expect(
        renderTemplate('{{ name }}', name: 'ws1', repoPath: '/repo'),
        equals('ws1'),
      );
    });

    test('substitutes branch as alias for name', () {
      expect(
        renderTemplate('{{ branch }}', name: 'ws1', repoPath: '/repo'),
        equals('ws1'),
      );
    });

    test('substitutes repo_path', () {
      expect(
        renderTemplate('{{ repo_path }}', name: 'ws1', repoPath: '/a/repo'),
        equals('/a/repo'),
      );
    });

    test('substitutes repo', () {
      expect(
        renderTemplate('{{ repo }}', name: 'ws1', repoPath: '/a/myrepo'),
        equals('myrepo'),
      );
    });

    test('applies sanitize filter', () {
      expect(
        renderTemplate(
          '{{ name | sanitize }}',
          name: 'feat/my-branch',
          repoPath: '/repo',
        ),
        equals('feat-my-branch'),
      );
    });

    test('applies hash_port filter', () {
      final result = renderTemplate(
        '{{ name | hash_port }}',
        name: 'test',
        repoPath: '/repo',
      );
      final port = int.parse(result);
      expect(port, greaterThanOrEqualTo(10000));
      expect(port, lessThan(20000));
    });

    test('hash_port is deterministic', () {
      final a = renderTemplate(
        '{{ name | hash_port }}',
        name: 'test',
        repoPath: '/repo',
      );
      final b = renderTemplate(
        '{{ name | hash_port }}',
        name: 'test',
        repoPath: '/repo',
      );
      expect(a, equals(b));
    });

    test('renders full worktree-path template', () {
      final result = renderTemplate(
        '{{ repo_path }}/../{{ name }}',
        name: 'feature',
        repoPath: '/home/user/project',
      );
      expect(result, equals('/home/user/project/../feature'));
    });

    test('renders unknown variables as empty string', () {
      expect(
        renderTemplate('{{ unknown }}', name: 'ws', repoPath: '/r'),
        equals(''),
      );
    });

    test('handles multiple variables in one string', () {
      final result = renderTemplate(
        '{{ repo }}/{{ name }}',
        name: 'ws1',
        repoPath: '/a/myrepo',
      );
      expect(result, equals('myrepo/ws1'));
    });
  });

  group('sanitize', () {
    test('replaces slashes with hyphens', () {
      expect(sanitize('feat/branch'), equals('feat-branch'));
    });

    test('handles multiple slashes', () {
      expect(sanitize('a/b/c'), equals('a-b-c'));
    });

    test('no-op for clean names', () {
      expect(sanitize('clean-name'), equals('clean-name'));
    });
  });

  group('hashPort', () {
    test('returns port in range', () {
      final port = hashPort('test');
      expect(port, greaterThanOrEqualTo(10000));
      expect(port, lessThan(20000));
    });

    test('different inputs produce different ports', () {
      expect(hashPort('alpha'), isNot(equals(hashPort('beta'))));
    });

    test('is deterministic', () {
      expect(hashPort('same'), equals(hashPort('same')));
    });
  });
}
