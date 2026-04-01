import 'package:dojjo/src/shell_integration.dart';
import 'package:test/test.dart';

void main() {
  group('initScript', () {
    test('returns bash script for bash', () {
      final script = initScript('bash');
      expect(script, contains('djo()'));
      expect(script, contains('--porcelain'));
      expect(script, contains('cd:'));
    });

    test('returns same script for zsh', () {
      expect(initScript('bash'), equals(initScript('zsh')));
    });

    test('returns fish script for fish', () {
      final script = initScript('fish');
      expect(script, contains('function djo'));
      expect(script, contains('--porcelain'));
      expect(script, contains('cd:'));
    });

    test('returns powershell script for pwsh', () {
      final script = initScript('pwsh');
      expect(script, contains('function djo'));
      expect(script, contains('Set-Location'));
      expect(script, contains('--porcelain'));
      expect(script, contains('cd:'));
    });

    test('powershell alias works', () {
      expect(initScript('powershell'), equals(initScript('pwsh')));
    });

    test('returns error for unknown shell', () {
      expect(initScript('ksh'), contains('Unsupported shell'));
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
      expect(defaultRcFile('bash'), endsWith('.bashrc'));
    });

    test('returns .zshrc for zsh', () {
      expect(defaultRcFile('zsh'), endsWith('.zshrc'));
    });

    test('returns config.fish for fish', () {
      expect(defaultRcFile('fish'), endsWith('config.fish'));
    });

    test('returns PowerShell profile for pwsh', () {
      expect(defaultRcFile('pwsh'), endsWith('Microsoft.PowerShell_profile.ps1'));
    });

    test('throws for unknown shell', () {
      expect(() => defaultRcFile('ksh'), throwsA(isA<ArgumentError>()));
    });
  });
}
