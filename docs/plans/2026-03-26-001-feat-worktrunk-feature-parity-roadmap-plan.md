---
title: "feat: Worktrunk Feature Parity Roadmap"
type: feat
status: active
date: 2026-03-26
---

# Worktrunk Feature Parity Roadmap

## Overview

A phased roadmap to bring dojjo (`djo`) to feature parity with worktrunk, adapted for jj's model. Each phase builds on the previous and delivers standalone value.

## Current State

dojjo is a Dart CLI compiled to a native binary via `dart compile exe`. It uses `args` for CLI parsing, `freezed` for immutable data classes, and `dart:io` for process execution.

| Command | Status | Notes |
|---------|--------|-------|
| `switch --create <name>` | Done | Creates workspace + bookmark, cd via shell wrapper |
| `switch <name>` | Done | Resolves path via jj, prompts to create if not found |
| `merge [-y] <target>` | Done | Squash, rebase, move bookmark, cleanup. Confirmation prompt, error recovery with `jj op undo` guidance |
| `list [--json]` | Done | Rich output with status symbols, bookmarks, file count. JSON mode. |
| `remove [-y] [--keep-bookmark] <name>` | Done | Resolves path via jj, deletes bookmark (optional), confirmation prompt |
| `update-stale` | Done | Wraps `jj workspace update-stale` |
| `shell init/install` | Done | Bash/zsh/fish support, cd wrapping for switch/merge |

**Global:** `--verbose`/`-v` flag prints jj commands to stderr.

**Missing:** Configuration, hooks, interactive picker, push integration, tab completion, divergent change detection.

## Worktrunk Features Not Applicable to jj

These git-specific features have no jj equivalent and should be **excluded**:

- **Fast-forward merge detection/handling** — jj uses only rebases
- **Staging area management** (`--stage all/tracked/none`) — jj has no index
- **Current branch / HEAD tracking** — jj doesn't have a "checked out branch" concept
- **Branch stash operations** — jj auto-snapshots the working copy
- **`wt step promote`** — swaps branch into main worktree (git worktree concept)
- **`wt step` namespace** — jj's model means fewer commands overall (no explicit commit, squash, rebase needed as standalone). Keep all commands top-level; namespace later only if crowding becomes a problem

## Worktrunk Features Needing jj Adaptation

| Worktrunk Feature | jj Adaptation |
|-------------------|---------------|
| Branch creation | Bookmark creation + explicit tracking |
| Merge (squash + rebase + ff) | Squash + rebase + move bookmark (no ff) |
| Remote branch tracking | `jj bookmark track` (must be explicit) |
| Conflict blocking | jj allows committable conflicts — warn but don't block |
| Stale worktree detection | `jj workspace update-stale` integration |
| Divergent states | Detect `divergent()` revset, offer resolution |
| CI status from GitHub | `jj git push` + GitHub API (bookmarks, not branches) |

## jj-Specific Features (No Worktrunk Equivalent)

These are opportunities unique to jj that dojjo should support:

- **Stale workspace detection and repair** — `jj workspace update-stale`
- **Divergent change detection** — warn when change IDs have multiple visible commits
- **Change ID display** — show stable change IDs alongside commit IDs in list
- **Operation log recovery** — leverage jj's operation log for undo after failed merge

---

## Phase 1: Core Polish

**Goal:** Make existing commands production-ready.

### 1.1 Confirmation Prompts ✅
- `-y`/`--yes` flag on `merge` and `remove`
- Shows what will happen before prompting `[y/N]`
- All status messages on stderr to preserve stdout for shell wrapper

### 1.2 Error Recovery for Merge ✅
- Each jj operation wrapped with error handling
- On failure: prints which step failed, advises `jj op undo`
- Workspace directory not deleted if earlier steps fail

### 1.3 Fix `remove` Path Resolution ✅
- Resolves workspace path via `jj workspace root --name <name>`
- Deletes associated bookmark (with `--keep-bookmark` flag to opt out)
- Shows actual directory path in confirmation prompt

### 1.4 Validate `switch` Without `--create` ✅
- Uses `jj workspace root --name <name>` to resolve real path
- If workspace doesn't exist, prompts to create it (workspace + bookmark)
- Stale workspace handling deferred to Phase 2.4

### 1.5 Verbose Mode ✅
- Add `--verbose`/`-v` global flag
- Print each `jj` command before executing it
- Show full stderr on failure

---

## Phase 2: Rich Status

**Goal:** Make `djo list` useful for monitoring multiple workspaces.

### 2.1 Enhanced List Output ✅
- Parse `jj workspace list` output and enrich with:
  - Current workspace marker
  - Bookmark name for each workspace
  - Change description (commit message)
  - Number of modified files
- Use `jj workspace list -T` with custom template to gather workspace state

### 2.2 Status Symbols ✅
Adapt worktrunk's status indicators for jj:
- `*` — current workspace
- `✘` — has conflicts
- `↕` — divergent change
- `!` — stale working copy (deferred to 2.4)
- Bookmark tracking state (tracked/untracked for remotes)

### 2.3 JSON Output ✅
- Add `--json` flag to `list`
- Structured output for programmatic consumption

### 2.4 Stale Workspace Detection ✅
- Stale indicator in `list` output not feasible (jj doesn't expose staleness in templates)
- `djo update-stale` convenience command wraps `jj workspace update-stale`

---

## Phase 3: Configuration

**Goal:** Make dojjo configurable per-user and per-project. All supported config keys must be compatible with worktrunk's `.config/wt.toml` format so that users with an existing worktrunk project config can use dojjo out-of-the-box without maintaining a separate config file.

### 3.0 Worktrunk Compatibility ✅
- Support worktrunk's TOML key names for overlapping features (adapted for jj where needed)
- Ignore worktrunk-only keys gracefully (no errors for `commit.stage`, `ci.platform`, etc.)
- At each level, both a dojjo-specific and a worktrunk config file are recognized
- If both exist at the same level, they are merged with dojjo-specific settings taking precedence

### 3.1 Configuration File Support ✅
Config files are loaded at two levels. At each level, both dojjo and worktrunk files are recognized and merged (dojjo takes precedence):

- **User config:**
  - `~/.config/dojjo/config.toml` (dojjo-specific, takes precedence)
  - `~/.config/worktrunk/config.toml` (worktrunk-compatible)
- **Project config:**
  - `.config/djo.toml` (dojjo-specific, takes precedence)
  - `.config/wt.toml` (worktrunk-compatible, version controlled)
- Project overrides user config
- Effective merge order (lowest to highest precedence): worktrunk user → dojjo user → worktrunk project → dojjo project

### 3.2 Configuration Keys (Phase 1) ✅
Worktrunk-compatible keys where applicable:
```toml
# Workspace path template (worktrunk: worktree-path)
worktree-path = "{{ repo_path }}/../{{ name }}"

# Merge settings (worktrunk-compatible)
[merge]
squash = true       # squash before merge (default: true)
rebase = true       # rebase onto target (default: true)
remove = true       # remove workspace after merge (default: true)
verify = true       # run hooks before merge (default: true)

# List settings (worktrunk-compatible)
[list]
url = "http://localhost:{{ name | hash_port }}"

# Aliases (worktrunk-compatible)
[aliases]
url = "echo http://localhost:{{ name | hash_port }}"
```

### 3.3 Template Variables ✅
Worktrunk-compatible where possible, with jj-specific additions:
- `{{ repo_path }}` — absolute repository path (worktrunk-compatible)
- `{{ repo }}` — repository directory name (worktrunk-compatible)
- `{{ name }}` — workspace/bookmark name (jj equivalent of `{{ branch }}`)
- `{{ branch }}` — alias for `{{ name }}` (worktrunk compatibility)
- `{{ name | sanitize }}` — filesystem-safe name (worktrunk-compatible)
- `{{ name | hash_port }}` — deterministic port 10000–19999 (worktrunk-compatible)

### 3.4 Environment Variable Overrides ✅
- `DOJJO_` prefix, SCREAMING_SNAKE_CASE (same convention as worktrunk's `WORKTRUNK_` prefix)
- e.g., `DOJJO_WORKTREE_PATH`, `DOJJO_MERGE__SQUASH`

### 3.5 Config Show Command ✅
- `djo config show` — display effective configuration for debugging
- Show which file each value came from (user vs project)

---

## Phase 4: Switch Enhancements

**Goal:** Match worktrunk's switch ergonomics.

### 4.1 Base Revision Support ✅
- `--base <revision>` flag on `switch --create`
- Create workspace from a specific revision, not just current

### 4.2 Execute After Switch ✅
- `-x`/`--execute <cmd>` flag
- Run a command in the new workspace after switching (e.g., launch editor, start agent)
- Template variable support in command string

### 4.3 Previous Workspace Shortcut ✅
- `djo switch -` — switch to the previously active workspace
- Stores last workspace in `.jj/djo-state`

### 4.4 Interactive Picker ✅
- `djo switch` with no arguments opens interactive selection
- Uses `fzf` when available, falls back to numbered list
- Saves current workspace as "previous" before switching

---

## Phase 5: Hook System

**Goal:** Automate workspace lifecycle tasks.

### 5.1 Hook Types ✅
Adapt worktrunk's 10 hooks, dropping git-specific ones:

| Hook | Blocking? | When |
|------|-----------|------|
| `pre-start` | Yes | Before new workspace setup completes |
| `post-start` | No | After workspace creation |
| `pre-switch` | Yes | Before switching to workspace |
| `post-switch` | No | After switching |
| `pre-merge` | Yes | Before merge (after rebase, before bookmark move) |
| `post-merge` | No | After merge and cleanup |
| `pre-remove` | No | Before workspace removal |
| `post-remove` | No | After workspace removal |

### 5.2 Hook Configuration ✅
```toml
# In .config/djo.toml or ~/.config/dojjo/config.toml
[hooks]
post-start = "npm install"

[hooks.pre-merge]
test = "cargo test"
lint = "cargo clippy"
```

### 5.3 Hook Execution ✅
- Pre-hooks: blocking, abort on failure
- Post-hooks: run sequentially, log errors but continue
- `--skip-hooks` flag to skip hooks on switch, merge, remove
- `djo hook <type>` for manual execution

### 5.4 Hook Template Variables ✅
- `{{ name }}` — workspace name
- `{{ path }}` — workspace path
- `{{ bookmark }}` — associated bookmark
- `{{ name | hash_port }}` — deterministic port (10000-19999)

---

## Phase 6: Push & Remote Integration

**Goal:** Complete the create-work-merge-push cycle.

### 6.1 Push Command ✅
- `djo push` — runs `jj git push` for the current workspace's bookmark
- `djo push --all` — push all tracked bookmarks

### 6.2 Bookmark Tracking ✅
- Auto-track bookmarks on creation (`jj bookmark track`)
- Show tracking state in `djo list` (deferred — needs remote bookmark info in template)

### 6.3 Merge + Push ✅
- `djo merge main --push` flag
- `merge.push = true` config default

---

## Phase 7: Advanced Features

**Goal:** Power-user features and polish.

### 7.1 Tab Completion
- Generate shell completions (bash/zsh/fish)
- Complete workspace names, bookmark names, shell types

### 7.2 Divergent Change Handling
- Detect divergent changes across workspaces
- Warn in `djo list` output
- `djo resolve` command or guidance for fixing divergence

### 7.3 LLM Commit Messages
- `djo commit` command with LLM integration for message generation
- Configurable provider (claude, codex, etc.)
- Custom prompt templates

### 7.4 For-Each
- `djo for-each <cmd>` — run a command in every workspace
- Parallel execution with output aggregation

### 7.5 Prune
- `djo prune` — remove workspaces whose bookmarks have been merged into the default bookmark

### 7.6 Copy Ignored ✅
- `djo copy-ignored <source> [target]` — copy gitignored files (build caches, `node_modules`, etc.) from one workspace to another
- Uses `cp -c` (APFS clonefile) on macOS for copy-on-write, falls back to regular copy elsewhere
- Groups by top-level directory for efficiency
- Excludes `.jj/` and `.git/` automatically
- Useful in `post-start` hooks to eliminate cold build times in new workspaces

---

## Implementation Priority Matrix

| Phase | Effort | Value | Dependencies |
|-------|--------|-------|--------------|
| 1: Core Polish | Small | High | None |
| 2: Rich Status | Medium | High | None |
| 3: Configuration | Medium | Medium | None (but enables 4, 5) |
| 4: Switch Enhancements | Medium | High | Phase 3 for templates |
| 5: Hook System | Large | Medium | Phase 3 |
| 6: Push & Remote | Small | Medium | None |
| 7: Advanced Features | Large | Medium | Phases 3, 5 |

**Recommended order:** Phase 1 → 2 → 3 → 6 → 4 → 5 → 7

Phases 1 and 2 are the highest value-to-effort ratio and make the tool usable day-to-day. Phase 6 is small and completes the core workflow. Phase 3 unlocks the template/config system needed by 4 and 5.

## Testing

Add tests incrementally alongside each phase. Test infrastructure should be set up early and expanded as features are added.

### Test Infrastructure
- Using `package:test` (Dart's standard test framework)
- Create a test helper that sets up a temporary jj repo with workspaces for integration tests

### Unit Tests
- `WorkspaceInfo` parsing from tab-separated jj template output
- JSON output formatting and escaping
- `formatWorkspace` display formatting (status symbols, markers, flags)
- Shell integration script generation
- Config file parsing and merging (Phase 3)
- Hook configuration parsing (Phase 5)
- Template variable substitution (Phase 3+)

### Integration Tests
- `JJ.run` executes commands and captures stdout/stderr correctly
- `workspaceListRich` returns correct `WorkspaceInfo` for a real jj repo
- `switch --create` creates workspace + bookmark
- `switch <name>` resolves workspace path
- `merge` performs squash + rebase + bookmark move + cleanup in order
- `remove` forgets workspace, deletes bookmark (unless `--keep-bookmark`), removes directory
- `update-stale` delegates to `jj workspace update-stale`
- Verbose mode prints jj commands to stderr
- Error recovery: partial merge failure leaves recoverable state

### Test Priority
Tests should follow the same recommended phase order. Start with unit tests for parsing/formatting (cheap, no jj dependency), then add integration tests for commands that modify state.

## Acceptance Criteria

- [ ] Each phase delivers standalone value and can be used without later phases
- [ ] All commands have confirmation prompts for destructive operations
- [ ] `djo list` shows meaningful status at a glance
- [ ] Configuration supports both user and project levels
- [ ] Shell integration works for bash, zsh, and fish
- [ ] Error messages guide users toward recovery (especially for merge failures)
- [ ] jj-specific features (stale detection, divergence) are surfaced to users
- [ ] Unit tests cover parsing, formatting, and configuration logic
- [ ] Integration tests cover each command's happy path
