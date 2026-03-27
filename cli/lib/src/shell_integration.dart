import 'dart:io';

const _bash = r'''djo() {
  case "$1" in
    switch|merge)
      local output
      output="$(command djo "$@")" || return $?
      if [ -n "$output" ]; then
        cd "$output" || return $?
      fi
      ;;
    *)
      command djo "$@"
      ;;
  esac
}''';

const _zsh = _bash;

const _fish = r'''function djo
  switch $argv[1]
    case switch merge
      set -l output (command djo $argv); or return $status
      if test -n "$output"
        cd $output; or return $status
      end
    case '*'
      command djo $argv
  end
end''';

const _evalLines = {
  'bash': r'eval "$(djo shell init bash)"',
  'zsh': r'eval "$(djo shell init zsh)"',
  'fish': 'djo shell init fish | source',
};

String initScript(String shell) {
  switch (shell) {
    case 'bash':
      return _bash;
    case 'zsh':
      return _zsh;
    case 'fish':
      return _fish;
    default:
      return 'Unsupported shell: $shell. Use bash, zsh, or fish.';
  }
}

String defaultRcFile(String shell) {
  final home = Platform.environment['HOME'] ?? '';
  switch (shell) {
    case 'bash':
      return '$home/.bashrc';
    case 'zsh':
      return '$home/.zshrc';
    case 'fish':
      return '$home/.config/fish/config.fish';
    default:
      throw ArgumentError('Unsupported shell: $shell');
  }
}

Future<void> install(String shell, String path) async {
  final evalLine = _evalLines[shell];
  if (evalLine == null) {
    throw ArgumentError('Unsupported shell: $shell. Use bash, zsh, or fish.');
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
