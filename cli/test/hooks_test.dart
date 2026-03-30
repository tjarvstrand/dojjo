import 'package:dojjo/src/hooks.dart';
import 'package:test/test.dart';

void main() {
  group('rewriteWorktrunkCommands', () {
    test('rewrites wt step to djo run', () {
      expect(rewriteWorktrunkCommands('wt step copy-ignored default'), equals('djo run copy-ignored default'));
    });

    test('rewrites wt to djo', () {
      expect(rewriteWorktrunkCommands('wt merge main'), equals('djo merge main'));
    });

    test('leaves non-wt commands unchanged', () {
      expect(rewriteWorktrunkCommands('npm install'), equals('npm install'));
    });

    test('handles wt in the middle of a command', () {
      expect(
        rewriteWorktrunkCommands('echo hello && wt step copy-ignored default'),
        equals('echo hello && djo run copy-ignored default'),
      );
    });

    test('does not match wt inside other words', () {
      expect(rewriteWorktrunkCommands('newt install'), equals('newt install'));
    });
  });
}
