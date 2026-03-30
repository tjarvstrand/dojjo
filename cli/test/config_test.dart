import 'package:dojjo/src/config.dart';
import 'package:test/test.dart';

void main() {
  group('parseToml', () {
    test('parses workspace-path', () {
      final config = parseToml('workspace-path = "../{{ name }}"');
      expect(config.workspacePath, equals('../{{ name }}'));
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
      expect(config.workspacePath, isEmpty);
      expect(config.merge.squash, isTrue);
      expect(config.merge.rebase, isTrue);
      expect(config.merge.remove, isTrue);
      expect(config.merge.verify, isTrue);
      expect(config.list.url, isEmpty);
      expect(config.aliases, isEmpty);
    });

    test('parses simple hook as single-step pipeline', () {
      final config = parseToml('''
[hooks]
post-start = "npm install"
''');
      expect(config.hooks, contains('post-start'));
      final pipeline = config.hooks['post-start']!;
      expect(pipeline, hasLength(1));
      expect(pipeline[0], hasLength(1));
      expect(pipeline[0][0].command, equals('npm install'));
    });

    test('parses named hooks as one step with parallel commands', () {
      final config = parseToml('''
[hooks.pre-merge]
test = "cargo test"
lint = "cargo clippy"
''');
      final pipeline = config.hooks['pre-merge']!;
      // One step with two parallel commands.
      expect(pipeline, hasLength(1));
      expect(pipeline[0], hasLength(2));
      expect(pipeline[0][0].name, equals('test'));
      expect(pipeline[0][0].command, equals('cargo test'));
      expect(pipeline[0][1].name, equals('lint'));
      expect(pipeline[0][1].command, equals('cargo clippy'));
    });

    test('parses list-of-maps as ordered pipeline', () {
      // TOML inline tables in an array.
      final config = parseToml('''
[hooks]
post-start = [{install = "npm install"}, {build = "npm run build", lint = "npm run lint"}]
''');
      final pipeline = config.hooks['post-start']!;
      // Two sequential steps.
      expect(pipeline, hasLength(2));
      // Step 1: one command.
      expect(pipeline[0], hasLength(1));
      expect(pipeline[0][0].command, equals('npm install'));
      // Step 2: two parallel commands.
      expect(pipeline[1], hasLength(2));
      expect(pipeline[1][0].name, equals('build'));
      expect(pipeline[1][1].name, equals('lint'));
    });

    test('parses mixed hook styles', () {
      final config = parseToml('''
[hooks]
post-start = "npm install"

[hooks.pre-merge]
test = "cargo test"
''');
      expect(config.hooks, hasLength(2));
      expect(config.hooks['post-start'], hasLength(1));
      expect(config.hooks['pre-merge'], hasLength(1));
    });

    test('parses ignore-worktrunk-hooks as boolean', () {
      final config = parseToml('ignore-worktrunk-hooks = true');
      expect(config.ignoreWorktrunkHooks, isA<IgnoreWorktrunkHooksAll>());
    });

    test('parses ignore-worktrunk-hooks as list', () {
      final config = parseToml('ignore-worktrunk-hooks = ["post-start", "pre-merge"]');
      final ignore = config.ignoreWorktrunkHooks as IgnoreWorktrunkHooksTypes;
      expect(ignore.types, equals(['post-start', 'pre-merge']));
    });

    test('defaults to not ignoring worktrunk hooks', () {
      final config = parseToml('');
      expect(config.ignoreWorktrunkHooks, isA<IgnoreWorktrunkHooksNone>());
    });

    test('ignores unknown keys gracefully', () {
      // worktrunk-only keys should not cause errors
      final config = parseToml('''
workspace-path = "test"

[commit]
stage = "all"

[ci]
platform = "github"
''');
      expect(config.workspacePath, equals('test'));
    });
  });

  group('mergeToml', () {
    test('override replaces non-empty values', () {
      final merged = mergeToml('workspace-path = "base"', 'workspace-path = "override"');
      expect(merged.workspacePath, equals('override'));
    });

    test('base preserved when override is empty', () {
      final merged = mergeToml('workspace-path = "base"', '');
      expect(merged.workspacePath, equals('base'));
    });

    test('base merge settings preserved when override omits them', () {
      final merged = mergeToml('''
[merge]
squash = false
rebase = false
''', 'workspace-path = "something"');
      expect(merged.merge.squash, isFalse);
      expect(merged.merge.rebase, isFalse);
    });

    test('base create-bookmark preserved when override omits it', () {
      final merged = mergeToml('create-bookmark = false', '');
      expect(merged.createBookmark, isFalse);
    });

    test('aliases are merged with override taking precedence', () {
      final merged = mergeToml(
        '''
[aliases]
a = "base-a"
b = "base-b"
''',
        '''
[aliases]
b = "override-b"
c = "override-c"
''',
      );
      expect(merged.aliases['a'], equals('base-a'));
      expect(merged.aliases['b'], equals('override-b'));
      expect(merged.aliases['c'], equals('override-c'));
    });

    test('merge settings from override take effect', () {
      final merged = mergeToml(
        '''
[merge]
squash = true
rebase = true
''',
        '''
[merge]
squash = false
''',
      );
      expect(merged.merge.squash, isFalse);
      expect(merged.merge.rebase, isTrue);
    });

    test('hooks from same type are appended', () {
      final merged = mergeToml(
        '''
[hooks]
post-start = "npm install"
''',
        '''
[hooks]
post-start = "djo copy-ignored --from default"
''',
      );
      final pipeline = merged.hooks['post-start']!;
      expect(pipeline, hasLength(2));
      expect(pipeline[0][0].command, equals('npm install'));
      expect(pipeline[1][0].command, equals('djo copy-ignored --from default'));
    });

    test('hooks from different types are preserved', () {
      final merged = mergeToml(
        '''
[hooks]
post-start = "npm install"
''',
        '''
[hooks.pre-merge]
test = "cargo test"
''',
      );
      expect(merged.hooks, hasLength(2));
      expect(merged.hooks, contains('post-start'));
      expect(merged.hooks, contains('pre-merge'));
    });
  });

  group('filterWorktrunkHooks', () {
    final hooks = <String, HookPipeline>{
      'post-start': [
        [HookEntry(name: 'install', command: 'npm install')],
      ],
      'pre-merge': [
        [HookEntry(name: 'test', command: 'cargo test')],
      ],
      'post-merge': [
        [HookEntry(name: 'notify', command: 'echo done')],
      ],
    };

    test('no-op when nothing ignored', () {
      final filtered = filterWorktrunkHooks(hooks, const IgnoreWorktrunkHooks.none());
      expect(filtered, hasLength(3));
    });

    test('ignores all', () {
      final filtered = filterWorktrunkHooks(hooks, const IgnoreWorktrunkHooks.all());
      expect(filtered, isEmpty);
    });

    test('ignores specific types', () {
      final filtered = filterWorktrunkHooks(hooks, const IgnoreWorktrunkHooks.types(['post-start', 'post-merge']));
      expect(filtered, hasLength(1));
      expect(filtered, contains('pre-merge'));
    });

    test('ignores types not present in hooks', () {
      final filtered = filterWorktrunkHooks(hooks, const IgnoreWorktrunkHooks.types(['nonexistent']));
      expect(filtered, hasLength(3));
    });

    test('ignores specific named hook', () {
      final namedHooks = <String, HookPipeline>{
        'pre-merge': [
          [HookEntry(name: 'test', command: 'cargo test'), HookEntry(name: 'lint', command: 'cargo clippy')],
        ],
      };
      final filtered = filterWorktrunkHooks(namedHooks, const IgnoreWorktrunkHooks.types(['pre-merge.lint']));
      expect(filtered, hasLength(1));
      expect(filtered['pre-merge']![0], hasLength(1));
      expect(filtered['pre-merge']![0][0].name, equals('test'));
    });

    test('removes hook type when all names are ignored', () {
      final namedHooks = <String, HookPipeline>{
        'pre-merge': [
          [HookEntry(name: 'lint', command: 'cargo clippy')],
        ],
      };
      final filtered = filterWorktrunkHooks(namedHooks, const IgnoreWorktrunkHooks.types(['pre-merge.lint']));
      expect(filtered, isEmpty);
    });

    test('mixes whole-type and named ignores', () {
      final filtered = filterWorktrunkHooks(hooks, const IgnoreWorktrunkHooks.types(['post-start', 'pre-merge.test']));
      // post-start removed entirely, pre-merge.test removed but type remains
      // if it had other entries (it doesn't in this fixture, so pre-merge is removed too)
      expect(filtered, contains('post-merge'));
      expect(filtered, isNot(contains('post-start')));
    });
  });
}
