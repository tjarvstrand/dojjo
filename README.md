# dojjo

A workspace manager for [jj](https://github.com/jj-vcs/jj), inspired by [worktrunk](https://worktrunk.dev/) for git.

## Prerequisites

- [jj](https://github.com/jj-vcs/jj)
- [mise](https://mise.jdx.dev/) (manages Java and sbt automatically)

## Building

```sh
cd cli
mise run build
```

The native binary is output to `cli/target/scala-3.3.7/djo`.

## Usage

Run `djo` from within a jj repository.

```sh
# Show available commands
djo

# Create a new workspace
djo add <name>

# List all workspaces
djo list

# Remove a workspace (forgets it and deletes the directory)
djo remove <name>
```

## Development

```sh
cd cli

# Compile without linking (faster feedback loop)
mise run compile

# Run tests
mise run test
```
