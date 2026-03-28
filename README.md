# dojjo

A workspace manager for [jj](https://github.com/jj-vcs/jj).

Inspired by [worktrunk](https://worktrunk.dev/), but adapted to jj workflows.

## Usage

### Commands

Run `djo` from within a jj repository.

```sh
djo switch                   # Create workspace + bookmark
djo list                     # List workspaces
djo merge                    # Squash, rebase, move bookmark, cleanup
djo remove                   # Remove workspace + bookmark
djo for-each                 # Run commands in every workspace
djo prune                    # Remove workspaces merged into default branch
djo copy-ignored             # Copy build caches from another workspace
djo update-stale             # Fix stale working copies
djo hook                     # Manually run hooks
djo config show              # Show effective configuration
djo shell                    # Shell integration
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
eval "$(djo shell completion zsh)"    # zsh
eval "$(djo shell completion bash)"   # bash
djo shell completion fish | source     # fish
djo shell completion pwsh | Invoke-Expression  # PowerShell
```

## Configuration

dojjo reads worktrunk-compatible TOML config files, merged in this precedence order (lowest to highest):

1. `~/.config/worktrunk/config.toml` (user, worktrunk-compatible)
2. `.config/wt.toml` (project, worktrunk-compatible)
3. `~/.config/dojjo/config.toml` (user, dojjo-specific)
4. `dojjo.toml` (project, dojjo-specific)
5. `dojjo.local.toml` (project, local overrides — add to `.gitignore`)

Unknown keys (e.g. worktrunk-only keys like `commit.stage`, `ci.platform`) are silently ignored.

### Config Keys

```toml
# Workspace path template
workspace-path = "{{ repo_path }}/../{{ name }}"

# Create bookmarks when creating workspaces (default: true)
create-bookmark = true

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

Used in `workspace-path`, hook commands, aliases, and `--execute`:

**Variables** available in all contexts (workspace-path, hooks, aliases, --execute):

| Variable | Description |
|----------|-------------|
| `name` | Workspace/bookmark name |
| `branch` | Alias for `name` (worktrunk compatibility) |
| `repo_path` | Absolute repository path |
| `repo` | Repository directory name |
| `worktree_path` / `workspace_path` | Workspace root path |
| `worktree_name` / `workspace_name` | Workspace directory name |
| `cwd` | Current working directory |

**Additional variables** available in hooks:

| Variable | Description |
|----------|-------------|
| `commit` | Current commit SHA |
| `short_commit` | Current commit SHA (7 chars) |
| `upstream` | Bookmark upstream (e.g. `name@origin`) |
| `default_branch` | Default branch/trunk name |
| `primary_worktree_path` / `primary_workspace_path` | Default workspace root path |
| `remote` | Primary remote name |
| `remote_url` | Primary remote URL |
| `target` | Merge target name (merge hooks only) |
| `target_worktree_path` / `target_workspace_path` | Merge target workspace path (merge hooks only) |
| `base` | Base branch (alias for default_branch) |
| `base_worktree_path` / `base_workspace_path` | Base workspace path |
| `hook_type` | Hook type (e.g. `pre-merge`) |
| `hook_name` | Hook command name |

**Filters** that can be applied to any string variable (e.g. `{{ name | sanitize }}`):

| Filter | Description |
|--------|-------------|
| `sanitize` | Filesystem-safe (slashes become hyphens) |
| `sanitize_db` | Database-safe (lowercase, underscores, hash suffix) |
| `hash_port` | Deterministic port in range 10000-19999 |

Templates use Jinja2 syntax via the [jinja](https://pub.dev/packages/jinja) package for compatibility with worktrunk.

### Environment Variable Overrides

| Config Key | Environment Variable |
|------------|---------------------|
| `workspace-path` | `DOJJO_WORKSPACE_PATH` |
| `merge.squash` | `DOJJO_MERGE__SQUASH` |
| `merge.push` | `DOJJO_MERGE__PUSH` |

### Hooks

Hooks run shell commands at lifecycle points, following worktrunk's pipeline model:

- **Pre-hooks** are blocking and sequential. Failure aborts the operation.
- **Post-hooks** run in the background. Errors are logged but don't abort.
- **Named hooks** (map form) run in parallel within a step.
- **Pipeline hooks** (list-of-maps) run steps sequentially, with parallel commands within each step.

```toml
# Single command
[hooks]
post-start = "npm install"

# Named commands run in parallel
[hooks.pre-merge]
test = "cargo test"
lint = "cargo clippy"

# Ordered pipeline: steps sequential, commands within each step parallel
[hooks]
post-start = [
    { install = "npm install" },
    { build = "npm run build", lint = "npm run lint" }
]
```

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

If you have both a worktrunk config and dojjo config in your repo, you can disable worktrunk hooks in dojjo if you don't
want to run both. Add this to your dojjo config (`dojjo.toml`):

```toml
# Disable all worktrunk hooks
ignore-worktrunk-hooks = true

# Disable specific hook types
ignore-worktrunk-hooks = ["post-start", "pre-merge"]

# Disable specific named hooks within a type
ignore-worktrunk-hooks = ["pre-merge.lint"]
```

Hook commands from worktrunk configs (`wt step copy-ignored`, `wt merge`, etc.) are automatically rewritten to their 
`djo` equivalents when running in dojjo.

### Copy Ignored

`djo copy-ignored --from <workspace>` copies untracked files (build caches, `node_modules`, etc.) from another workspace:

- Uses APFS clonefile (`cp -c`) on macOS for near-instant copy-on-write
- Skips existing files by default (use `--force` to overwrite)
- Respects `.worktreeinclude` whitelist and `[step.copy-ignored] exclude` config
- Use `--dry-run` to preview

## Worktrunk Compatibility

dojjo is designed so that projects with an existing `.config/wt.toml` should work out of the box. Config file format, 
keys, and template syntax are compatible with worktrunk.

Worktrunk features that don't apply to jj are not supported.

## Development

Make sure you have [mise](https://mise.jdx.dev/) installed.

```sh
cd cli
mise run test       # Run tests
mise run analyze    # Static analysis (--fatal-infos)
mise run generate   # Freezed code generation (pass 'watch' for continuous)
mise run compile    # Check compilation
```

The native binary is output to `cli/build/djo`.

## Future Work

- CI status in `list --full` output (GitHub/GitLab pipeline status per bookmark)
- Agent tool integrations (Claude Code, etc.)
