# dojjo

A workspace manager for [jj](https://github.com/jj-vcs/jj), inspired by [worktrunk](https://worktrunk.dev/) for git.

## Prerequisites

- [jj](https://github.com/jj-vcs/jj)
- [mise](https://mise.jdx.dev/) (manages Dart SDK automatically)

## Building

```sh
cd cli
mise run build
```

The native binary is output to `cli/build/djo`.

## Usage

Run `djo` from within a jj repository.

```sh
djo switch -c feature       # Create workspace + bookmark
djo switch feature           # Switch to existing workspace
djo switch                   # Interactive picker (fzf or fallback)
djo switch -                 # Switch to previous workspace
djo switch -c -b @- feature  # Create workspace from a specific revision
djo switch -x 'npm install' feature  # Run command after switching
djo list                     # List workspaces with status
djo list --json              # JSON output
djo merge -y main            # Squash, rebase, move bookmark, cleanup
djo merge main --push        # Merge and push
djo push                     # Push current bookmark
djo push --all               # Push all tracked bookmarks
djo remove -y feature        # Remove workspace + bookmark
djo for-each 'npm test'      # Run command in every workspace
djo prune -y                 # Remove workspaces merged into trunk
djo copy-ignored --from main # Copy build caches from another workspace
djo update-stale             # Fix stale working copies
djo hook post-start          # Manually run hooks
djo config show              # Show effective configuration
djo completion zsh            # Output shell completions
djo shell init zsh            # Output shell integration (cd wrapping)
```

### List Output

`djo list` shows each workspace with status indicators:

- `*` current workspace
- `✘` has conflicts
- `↕` divergent change (change ID with multiple visible commits)

Example: `* feature [feat-branch] ✘ Add login page (3 files)`

### Merge Behavior

`djo merge <target>` performs these steps in order:

1. Squash (configurable)
2. Rebase onto target (configurable)
3. Move bookmark to target
4. Forget workspace
5. Delete workspace directory (configurable)
6. Push (if `--push` or `merge.push = true`)

On failure, advises `jj op undo` to revert.

## Shell Integration

Add to your shell rc file for `cd` wrapping on `switch` and `merge`:

```sh
eval "$(djo shell init zsh)"    # zsh
eval "$(djo shell init bash)"   # bash
djo shell init fish | source     # fish
. (djo shell init pwsh | Out-String)  # PowerShell
```

Tab completion:

```sh
eval "$(djo completion zsh)"    # zsh
eval "$(djo completion bash)"   # bash
djo completion fish | source     # fish
djo completion pwsh | Invoke-Expression  # PowerShell
```

## Configuration

dojjo reads worktrunk-compatible TOML config files at two levels, merged in this precedence order (lowest to highest):

1. `~/.config/worktrunk/config.toml` (user, worktrunk-compatible)
2. `~/.config/dojjo/config.toml` (user, dojjo-specific)
3. `.config/wt.toml` (project, worktrunk-compatible)
4. `.config/djo.toml` (project, dojjo-specific)

Unknown keys (e.g. worktrunk-only keys like `commit.stage`, `ci.platform`) are silently ignored.

### Config Keys

```toml
# Workspace path template
worktree-path = "{{ repo_path }}/../{{ name }}"

[merge]
squash = true       # Squash before merge (default: true)
rebase = true       # Rebase onto target (default: true)
remove = true       # Remove workspace after merge (default: true)
verify = true       # Run pre-merge hooks (default: true)
push = false        # Push after merge (default: false)

[list]
url = "http://localhost:{{ name | hash_port }}"

[step.copy-ignored]
exclude = [".cache/", ".turbo/"]

[hooks]
post-start = "npm install"

[hooks.pre-merge]
test = "cargo test"
lint = "cargo clippy"

[aliases]
url = "echo http://localhost:{{ name | hash_port }}"
```

### Template Variables

Used in `worktree-path`, hook commands, aliases, and `--execute`:

| Variable | Description |
|----------|-------------|
| `{{ name }}` | Workspace/bookmark name |
| `{{ branch }}` | Alias for `name` (worktrunk compatibility) |
| `{{ repo_path }}` | Absolute repository path |
| `{{ repo }}` | Repository directory name |
| `{{ name \| sanitize }}` | Filesystem-safe name (slashes become hyphens) |
| `{{ name \| sanitize_db }}` | Database-safe name (lowercase, underscores, hash suffix) |
| `{{ name \| hash_port }}` | Deterministic port in range 10000-19999 |
| `{{ workspace_index }}` | Persistent integer index for the workspace (reusable after removal) |

Full Jinja2 syntax is supported (conditionals, loops, built-in filters) via the [jinja](https://pub.dev/packages/jinja) package for compatibility with worktrunk's minijinja templates.

### Environment Variable Overrides

`DOJJO_` prefix with `SCREAMING_SNAKE_CASE`. Nested keys use double underscores:

| Config Key | Environment Variable |
|------------|---------------------|
| `worktree-path` | `DOJJO_WORKTREE_PATH` |
| `merge.squash` | `DOJJO_MERGE__SQUASH` |
| `merge.push` | `DOJJO_MERGE__PUSH` |

### Hooks

Hooks run shell commands at lifecycle points. Pre-hooks are blocking (abort on failure), post-hooks log errors but continue.

| Hook | When | Blocking |
|------|------|----------|
| `pre-start` | Before workspace creation | Yes |
| `post-start` | After workspace creation | No |
| `pre-switch` | Before switching | Yes |
| `post-switch` | After switching | No |
| `pre-merge` | Before merge | Yes |
| `post-merge` | After merge | No |
| `pre-remove` | Before removal | No |
| `post-remove` | After removal | No |

Use `--skip-hooks` on switch, merge, or remove to skip hooks. Use `djo hook <type>` to run hooks manually.

Hook commands from worktrunk configs (`wt step copy-ignored`, `wt merge`, etc.) are automatically rewritten to their `djo` equivalents.

### Copy Ignored

`djo copy-ignored --from <workspace>` copies untracked files (build caches, `node_modules`, etc.) from another workspace:

- Uses APFS clonefile (`cp -c`) on macOS for near-instant copy-on-write
- Skips existing files by default (use `--force` to overwrite)
- Respects `.worktreeinclude` whitelist and `[step.copy-ignored] exclude` config
- Use `--dry-run` to preview

## Worktrunk Compatibility

dojjo is designed so that projects with an existing `.config/wt.toml` work out of the box. Config file format, TOML keys, and Jinja template syntax are compatible with worktrunk.

Worktrunk features that don't apply to jj are excluded:

- Fast-forward merge detection (jj uses only rebases)
- Staging area management (jj has no index)
- Branch stash operations (jj auto-snapshots)
- `wt step promote` (git worktree concept)

## Development

```sh
cd cli
mise run test       # Run tests
mise run analyze    # Static analysis (--fatal-infos)
mise run generate   # Freezed code generation (pass 'watch' for continuous)
mise run compile    # Check compilation
```

## Future Work

- CI status in `list --full` output (GitHub/GitLab pipeline status per bookmark)
- Agent tool integrations (Claude Code, etc.)
