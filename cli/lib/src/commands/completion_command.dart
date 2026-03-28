import 'dart:io';

import 'package:args/command_runner.dart';

class CompletionCommand extends Command<void> {
  @override
  String get name => 'completion';

  @override
  String get description => 'Output shell completion script (bash, zsh, fish, or pwsh)';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Missing required argument: <shell>');
    }
    final shell = rest.first;
    final script = switch (shell) {
      'bash' => _bash,
      'zsh' => _zsh,
      'fish' => _fish,
      'pwsh' || 'powershell' => _pwsh,
      _ => null,
    };
    if (script == null) {
      usageException('Unsupported shell: $shell. Use bash, zsh, fish, or pwsh.');
    }
    stdout.writeln(script);
  }
}

const _bash = r'''_djo_complete() {
  local cur prev commands
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  commands="config copy-ignored for-each help hook list merge prune remove shell switch update-stale"

  case "${COMP_WORDS[1]}" in
    switch|remove|copy-ignored|hook)
      # Complete with workspace names
      COMPREPLY=( $(compgen -W "$(djo list --json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)" -- "$cur") )
      return 0
      ;;
    merge)
      # Complete with bookmark names
      COMPREPLY=( $(compgen -W "$(jj bookmark list --no-pager -T 'name ++ "\n"' 2>/dev/null)" -- "$cur") )
      return 0
      ;;
    shell)
      COMPREPLY=( $(compgen -W "completion init install" -- "$cur") )
      return 0
      ;;
  esac

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
  fi
}
complete -F _djo_complete djo''';

const _zsh = r'''#compdef djo

_djo() {
  local -a commands
  commands=(
    'config:Configuration management'
    'copy-ignored:Copy untracked files between workspaces'
    'for-each:Run a command in every workspace'
    'help:Display help'
    'hook:Manually run hooks'
    'list:List all jj workspaces'
    'merge:Squash, rebase, move bookmark, and clean up'
    'prune:Remove merged workspaces'
    'remove:Forget a workspace and delete its directory'
    'shell:Shell integration commands'
    'switch:Create or switch to a workspace'
    'update-stale:Update stale workspaces'
  )

  _arguments -C \
    '-v[Verbose output]' \
    '--verbose[Verbose output]' \
    '-h[Show help]' \
    '--help[Show help]' \
    '1:command:->command' \
    '*::arg:->args'

  case $state in
    command)
      _describe 'command' commands
      ;;
    args)
      case $words[1] in
        switch|remove|copy-ignored|hook)
          local -a workspaces
          workspaces=(${(f)"$(djo list --json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)"})
          _describe 'workspace' workspaces
          ;;
        merge)
          local -a bookmarks
          bookmarks=(${(f)"$(jj bookmark list --no-pager -T 'name ++ "\n"' 2>/dev/null)"})
          _describe 'bookmark' bookmarks
          ;;
        shell)
          _describe 'subcommand' '(completion init install)'
          ;;
      esac
      ;;
  esac
}

_djo "$@"''';

const _fish = r'''complete -c djo -f

# Commands
complete -c djo -n __fish_use_subcommand -a config -d 'Configuration management'
complete -c djo -n __fish_use_subcommand -a copy-ignored -d 'Copy untracked files between workspaces'
complete -c djo -n __fish_use_subcommand -a for-each -d 'Run a command in every workspace'
complete -c djo -n __fish_use_subcommand -a help -d 'Display help'
complete -c djo -n __fish_use_subcommand -a hook -d 'Manually run hooks'
complete -c djo -n __fish_use_subcommand -a list -d 'List all jj workspaces'
complete -c djo -n __fish_use_subcommand -a merge -d 'Squash, rebase, move bookmark, and clean up'
complete -c djo -n __fish_use_subcommand -a prune -d 'Remove merged workspaces'
complete -c djo -n __fish_use_subcommand -a remove -d 'Forget a workspace and delete its directory'
complete -c djo -n __fish_use_subcommand -a shell -d 'Shell integration commands'
complete -c djo -n __fish_use_subcommand -a switch -d 'Create or switch to a workspace'
complete -c djo -n __fish_use_subcommand -a update-stale -d 'Update stale workspaces'

# Global flags
complete -c djo -s v -l verbose -d 'Verbose output'

# Workspace name completions
for cmd in switch remove copy-ignored hook
  complete -c djo -n "__fish_seen_subcommand_from $cmd" -a "(djo list --json 2>/dev/null | string match -r '\"name\":\"[^\"]*\"' | string replace -r '\"name\":\"([^\"]*)\"' '$1')"
end

# Bookmark completions for merge
complete -c djo -n '__fish_seen_subcommand_from merge' -a "(jj bookmark list --no-pager -T 'name ++ \"\n\"' 2>/dev/null)"

# Shell subcommands
complete -c djo -n '__fish_seen_subcommand_from shell' -a 'completion init install' ''';

const _pwsh = r'''Register-ArgumentCompleter -CommandName djo -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  $commands = @(
    @{Name='config'; Tooltip='Configuration management'}
    @{Name='copy-ignored'; Tooltip='Copy untracked files between workspaces'}
    @{Name='for-each'; Tooltip='Run a command in every workspace'}
    @{Name='help'; Tooltip='Display help'}
    @{Name='hook'; Tooltip='Manually run hooks'}
    @{Name='list'; Tooltip='List all jj workspaces'}
    @{Name='merge'; Tooltip='Squash, rebase, move bookmark, and clean up'}
    @{Name='prune'; Tooltip='Remove merged workspaces'}
    @{Name='remove'; Tooltip='Forget a workspace and delete its directory'}
    @{Name='shell'; Tooltip='Shell integration commands'}
    @{Name='switch'; Tooltip='Create or switch to a workspace'}
    @{Name='update-stale'; Tooltip='Update stale workspaces'}
  )
  $elements = $commandAst.CommandElements
  if ($elements.Count -le 2) {
    $commands | Where-Object { $_.Name -like "$wordToComplete*" } |
      ForEach-Object { [System.Management.Automation.CompletionResult]::new($_.Name, $_.Name, 'ParameterValue', $_.Tooltip) }
  }
}''';
