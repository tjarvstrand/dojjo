import 'package:dojjo/src/shell_integration.dart';
import 'package:test/test.dart';

void main() {
  group('initScript', () {
    test('returns bash script for bash', () {
      final script = initScript('bash');
      expect(script, contains('djo()'));
      expect(script, contains('case'));
      expect(script, contains('switch|merge'));
    });

    test('returns same script for zsh', () {
      expect(initScript('bash'), equals(initScript('zsh')));
    });

    test('returns fish script for fish', () {
      final script = initScript('fish');
      expect(script, contains('function djo'));
      expect(script, contains('switch merge'));
    });

    test('returns error for unknown shell', () {
      expect(initScript('powershell'), contains('Unsupported shell'));
    });

    test('bash script wraps switch and merge with cd', () {
      expect(initScript('bash'), contains(r'cd "$output"'));
    });

    test('fish script wraps switch and merge with cd', () {
      expect(initScript('fish'), contains(r'cd $output'));
    });

    test('bash script uses command to bypass function', () {
      expect(initScript('bash'), contains('command djo'));
    });

    test('fish script uses command to bypass function', () {
      expect(initScript('fish'), contains('command djo'));
    });
  });

  group('defaultRcFile', () {
    test('returns .bashrc for bash', () {
      expect(defaultRcFile('bash'), endsWith('/.bashrc'));
    });

    test('returns .zshrc for zsh', () {
      expect(defaultRcFile('zsh'), endsWith('/.zshrc'));
    });

    test('returns config.fish for fish', () {
      expect(
        defaultRcFile('fish'),
        endsWith('/.config/fish/config.fish'),
      );
    });

    test('throws for unknown shell', () {
      expect(
        () => defaultRcFile('powershell'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
