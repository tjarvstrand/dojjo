# dojjo

A CLI tool for managing jj (Jujutsu) workspaces, inspired by worktrunk but adapted for jj's model.

## Naming

Use descriptive variable names, avoiding abbreviations. Don't unnecessarily prefix or qualify names when the enclosing function/class already makes the meaning clear. E.g. `_createWorkspace(String name)` not `_createWorkspace(String wsName)`. Only qualify when there's actual ambiguity.

## Null Safety

Avoid the null check operator (`!`) except in deserialization code. Use proper null checks with descriptive error messages instead.

## Worktrunk Compatibility

Keep compatibility with worktrunk's **configuration files** (`.config/wt.toml` format, TOML key names, Jinja template syntax), but don't copy worktrunk's CLI flags or command structure. dojjo should have its own ergonomics suited to jj's workflow. When adding flags or commands, choose names that are descriptive in dojjo's context. When parsing config, match worktrunk's TOML keys and template syntax exactly.

## Style

Prefer `isEmpty` over `isNotEmpty` in conditionals. Avoid named imports (`as X`) unless there are actual naming conflicts. Exception: `package:path/path.dart as p` is standard Dart convention.

## Changelog

New entries always go under the `## [Unreleased]` heading, never under an already-released version.

## Testing

Always add tests covering new functionality or fixes for defects.

## Verification

After making changes, always run both:
```
mise run analyze       # Static analysis
mise run format-check  # Formatting
```

## Build

The CLI lives in `cli/`. It's a Dart project compiled to a native binary.

```
mise run build      # dart compile exe
mise run test       # dart test
mise run analyze    # dart analyze --fatal-infos
mise run generate   # build_runner (freezed codegen)
```
