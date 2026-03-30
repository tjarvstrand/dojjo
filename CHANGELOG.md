# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.1/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2026-03-30

### Fixed

- Merge hooks now receive the current workspace name instead of the target branch as `{{ name }}`/`{{ branch }}`

## [0.1.1] - 2026-03-30

### Fixed

- Post-remove and post-merge hooks now run from the primary workspace directory instead of the deleted directory
- `parseWorkspaceList` throws a descriptive `FormatException` instead of a `RangeError` on malformed jj output
- Previous workspace state is no longer saved until the switch actually succeeds
- `switch -x` command output is now written to stdout instead of stderr

## [0.1.0+2] - 2026-03-29

### Added

- `create-bookmark` config option and `--bookmark`/`--no-bookmark` flag on `switch -c`
- `dojjo.local.toml` project-level config for local overrides
- Install script (`install.sh`) with shell integration prompt
- Standard-readme compliant README

### Changed

- `completion` is now a subcommand of `shell` (`djo shell completion`)
- Project config moved from `.config/djo.toml` to `dojjo.toml`
- Config key `worktree-path` renamed to `workspace-path` (old key still accepted)
- Environment variable `DOJJO_WORKTREE_PATH` renamed to `DOJJO_WORKSPACE_PATH`
- `hash_port` template filter now returns an integer instead of a string
- Commands that don't produce output now return void
- Process execution unified through `runProcess` in `platform.dart`
- Errors bubble up as exceptions instead of calling `exit()` directly

### Removed

- `push` command (use `jj git push` directly)
- `workspace_index` template variable and persistent index state file

## [0.1.0] - 2026-03-28

### Added

- `switch` command with workspace creation, interactive picker, and `-` for previous
- `list` command with conflict/divergent indicators and JSON output
- `merge` command with configurable squash/rebase/push pipeline
- `remove` command with bookmark cleanup
- `for-each` command to run commands across all workspaces
- `prune` command to remove merged workspaces
- `copy-ignored` command with APFS clonefile support
- `update-stale` command
- `hook` command for manual hook execution
- `config show` command
- Shell integration for bash, zsh, fish, and PowerShell
- Tab completion for bash, zsh, fish, and PowerShell
- Worktrunk config compatibility (`.config/wt.toml` format)
- Hook pipeline system (pre/post hooks, parallel/sequential execution)
- Jinja2 template variables and filters (`sanitize`, `sanitize_db`, `hash_port`)
- Environment variable overrides for config values

[Unreleased]: https://github.com/tjarvstrand/dojjo/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/tjarvstrand/dojjo/releases/tag/v0.1.2
[0.1.1]: https://github.com/tjarvstrand/dojjo/releases/tag/v0.1.1
[0.1.0+2]: https://github.com/tjarvstrand/dojjo/releases/tag/v0.1.0+2
[0.1.0]: https://github.com/tjarvstrand/dojjo/releases/tag/v0.1.0
