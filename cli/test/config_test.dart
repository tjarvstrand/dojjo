import 'package:dojjo/src/config.dart';
import 'package:test/test.dart';

void main() {
  group('parseToml', () {
    test('parses worktree-path', () {
      final config = parseToml('worktree-path = "../{{ name }}"');
      expect(config.worktreePath, equals('../{{ name }}'));
    });

    test('parses merge settings', () {
      final config = parseToml('''
[merge]
squash = false
rebase = false
remove = false
verify = false
''');
      expect(config.merge.squash, isFalse);
      expect(config.merge.rebase, isFalse);
      expect(config.merge.remove, isFalse);
      expect(config.merge.verify, isFalse);
    });

    test('parses list url', () {
      final config = parseToml('''
[list]
url = "http://localhost:{{ name | hash_port }}"
''');
      expect(config.list.url, contains('hash_port'));
    });

    test('parses aliases', () {
      final config = parseToml('''
[aliases]
url = "echo hello"
deploy = "make deploy"
''');
      expect(config.aliases, hasLength(2));
      expect(config.aliases['url'], equals('echo hello'));
      expect(config.aliases['deploy'], equals('make deploy'));
    });

    test('defaults for missing keys', () {
      final config = parseToml('');
      expect(config.worktreePath, isEmpty);
      expect(config.merge.squash, isTrue);
      expect(config.merge.rebase, isTrue);
      expect(config.merge.remove, isTrue);
      expect(config.merge.verify, isTrue);
      expect(config.list.url, isEmpty);
      expect(config.aliases, isEmpty);
    });

    test('ignores unknown keys gracefully', () {
      // worktrunk-only keys should not cause errors
      final config = parseToml('''
worktree-path = "test"

[commit]
stage = "all"

[ci]
platform = "github"
''');
      expect(config.worktreePath, equals('test'));
    });
  });

  group('mergeConfigs', () {
    test('override replaces non-empty values', () {
      final base = parseToml('worktree-path = "base"');
      final override = parseToml('worktree-path = "override"');
      final merged = mergeConfigs(base, override);
      expect(merged.worktreePath, equals('override'));
    });

    test('base preserved when override is empty', () {
      final base = parseToml('worktree-path = "base"');
      final override = parseToml('');
      final merged = mergeConfigs(base, override);
      expect(merged.worktreePath, equals('base'));
    });

    test('aliases are merged with override taking precedence', () {
      final base = parseToml('''
[aliases]
a = "base-a"
b = "base-b"
''');
      final override = parseToml('''
[aliases]
b = "override-b"
c = "override-c"
''');
      final merged = mergeConfigs(base, override);
      expect(merged.aliases['a'], equals('base-a'));
      expect(merged.aliases['b'], equals('override-b'));
      expect(merged.aliases['c'], equals('override-c'));
    });

    test('merge settings from override take effect', () {
      final base = parseToml('''
[merge]
squash = true
rebase = true
''');
      final override = parseToml('''
[merge]
squash = false
''');
      final merged = mergeConfigs(base, override);
      expect(merged.merge.squash, isFalse);
      // rebase uses override's default (true)
      expect(merged.merge.rebase, isTrue);
    });
  });
}
