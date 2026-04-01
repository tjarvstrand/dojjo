import 'dart:io';

import 'package:dojjo/src/platform.dart';
import 'package:path/path.dart' as p;

const _bash = r'''djo() {
  local output line
  output="$(command djo --porcelain "$@")" || return $?
  while IFS= read -r line; do
    case "$line" in
      cd:*) cd "${line#cd:}" || return $? ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <<< "$output"
}''';

const _zsh = _bash;

const _fish = r'''function djo
  set -l output (command djo --porcelain $argv); or return $status
  for line in $output
    switch $line
      case 'cd:*'
        cd (string sub -s 4 $line); or return $status
      case '*'
        echo $line
    end
  end
end''';

const _powershell = r'''function djo {
  $djoBin = (Get-Command djo.exe).Source
  $output = & $djoBin --porcelain @args
  if ($LASTEXITCODE -ne 0) { return }
  foreach ($line in $output) {
    if ($line.StartsWith("cd:")) {
      Set-Location $line.Substring(3)
    } else {
      Write-Output $line
    }
  }
}''';

const _evalLines = {
  'bash': r'eval "$(djo shell init bash)"',
  'zsh': r'eval "$(djo shell init zsh)"',
  'fish': 'djo shell init fish | source',
  'pwsh': '. (djo shell init pwsh | Out-String)',
};

String initScript(String shell) => switch (shell) {
  'bash' => _bash,
  'zsh' => _zsh,
  'fish' => _fish,
  'pwsh' || 'powershell' => _powershell,
  _ => 'Unsupported shell: $shell. Use bash, zsh, fish, or pwsh.',
};

String defaultRcFile(String shell) {
  final home = homeDirectory;
  return switch (shell) {
    'bash' => p.join(home, '.bashrc'),
    'zsh' => p.join(home, '.zshrc'),
    'fish' => p.join(home, '.config', 'fish', 'config.fish'),
    'pwsh' || 'powershell' => p.join(home, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1'),
    _ => throw ArgumentError('Unsupported shell: $shell'),
  };
}

Future<void> install(String shell, String path) async {
  final evalLine = _evalLines[shell];
  if (evalLine == null) {
    throw ArgumentError('Unsupported shell: $shell. Use bash, zsh, fish, or pwsh.');
  }

  final file = File(path);
  if (await file.exists()) {
    final content = await file.readAsString();
    if (content.contains('djo shell init')) {
      throw Exception('Shell integration already present in $path');
    }
  }

  final parent = file.parent;
  if (!await parent.exists()) {
    await parent.create(recursive: true);
  }

  await file.writeAsString('\n# dojjo shell integration\n$evalLine\n', mode: FileMode.append);
}
