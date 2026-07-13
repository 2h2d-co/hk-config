# hk-config

Shared [hk](https://hk.jdx.dev/) configuration for 2h2d repositories.

These configs are committed Pkl modules that project repos can amend/import. They are different from `~/.config/hk/config.pkl`: this repo is for team-shared policy, not per-user preferences.

## Files

- `Base.pkl` — general hygiene, secret-safety, and conventional commit checks for most repos.
- `Python.pkl` — `Base.pkl` plus Python syntax/debug checks and optional Ruff checks.
- `TypeScript.pkl` — `Base.pkl` plus optional Oxfmt, Oxlint, and TypeScript checks.
- `Go.pkl` — `Base.pkl` plus optional Go formatting, module, vet, and vulnerability checks.
- `GitHubActions.pkl` — `Base.pkl` plus optional GitHub Actions linting and security checks.
- `Shell.pkl` — `Base.pkl` plus optional shfmt and ShellCheck for `.sh`/`.bash` files.
- `PklProject` — Pkl package metadata for release artifacts.
- `cog.toml` and `CHANGELOG.md` — Cocogitto release/changelog configuration for this repo.
- `AGENTS.md` — repository conventions for coding agents and humans.
- `LICENSE` — MIT license for this repo.

## Architecture

hk uses one project config file and Pkl permits only one module-level `amends` clause. Treat `Base.pkl` as the shared base to amend when composing multiple presets. Stack-specific files are both convenience presets for focused repos and step libraries for mixed repos: import their exported step mappings, then spread them into one hooks map.

## Conditional external tools

hk conditions are `expr` strings. These configs use `step_condition` in two ways:

- command-optional tools use `Base.optionalCommand(...)` and skip when the executable is not on `PATH`.
- project-file-conditioned tools use `Base.whenFileExists(...)` and run when the repo contains the marker file; if the command is missing, the step fails.

The base config runs `gitleaks` opportunistically when installed. When `mise.toml` exists, `mise-installed` checks that `mise` is available on every hook run, and the `mise` formatter runs when mise config files are in the hook's file set.

## Commit messages

`Base.pkl` adds a `commit-msg` hook. If `cog` is available, it uses hk's `cocogitto-commit-msg` builtin and Cocogitto validates according to the repo's `cog.toml`. If `cog` is not available, it falls back to hk's `check-conventional-commit` utility with the standard Conventional Commit types plus `release`.

Allowed types for the fallback hk utility path:

```text
build,chore,ci,docs,feat,fix,perf,refactor,revert,style,test,release
```

If a repo uses Cocogitto and wants `release: ...` commits, configure Cocogitto to allow that custom type in `cog.toml`. This repo's `cog.toml` allows `release: vX.Y.Z` commits and sets `tag_prefix = "v"` so release tags are `vX.Y.Z`.

## Tool-specific vs generic config checks

Prefer domain-specific tools when they exist, then add generic formatters only for files without a better owner:

- `mise fmt` understands mise config locations and intended formatting. Use TOML tools such as `taplo` or `tombi` for general TOML files, not as a replacement for the mise step.
- `actionlint` and `zizmor` understand GitHub Actions semantics. The shared zizmor step uses its pedantic persona and audits suppressed findings with `--no-ignores`. Generic YAML tools can be useful in a future `Yaml.pkl`, but they do not replace Actions-specific checks.
- `hk validate` checks hk config semantics after Pkl evaluation. `pkl_format` is useful for formatting Pkl source, and `pkl eval` checks generic Pkl evaluation, but neither is a substitute for `hk validate` on hk config files.
- Avoid two generic formatters owning the same file unless their output is stable together; if multiple fixers touch the same files, order them with `depends`.

## Use from a repo

Use the Pkl package artifact published with each release. The Git tag includes the `v` prefix, while the Pkl package version does not:

```text
package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0
```

### Base only

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Base.pkl"
```

### Python repo

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Python.pkl"
```

### TypeScript repo

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/TypeScript.pkl"
```

### Go repo

The Go preset includes formatting, module tidiness, vetting, optional vulnerability checks, and `golangci-lint` when installed.

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Go.pkl"
```

### GitHub Actions repo

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/GitHubActions.pkl"
```

### Shell scripts repo

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Shell.pkl"
```

### Compose multiple configs

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Base.pkl"

import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Base.pkl" as Base
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Python.pkl" as Python
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/TypeScript.pkl" as TypeScript
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Go.pkl" as Go
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/GitHubActions.pkl" as GitHubActions
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Shell.pkl" as Shell

local steps = (Base.baseSteps) {
  ...Python.pythonSteps
  ...TypeScript.typeScriptSteps
  ...Go.goSteps
  ...GitHubActions.gitHubActionsSteps
  ...Shell.shellSteps
}

hooks = Base.defaultHooks(true, steps)
```

### Add repo-local steps

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Python.pkl"

import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Base.pkl" as Base
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.0/hk-config@0.1.0#/Python.pkl" as Python
import "package://github.com/jdx/hk/releases/download/v1.48.0/hk@1.48.0#/Builtins.pkl"

local repoSteps = new Mapping<String, Step> {
  ["taplo"] = Base.optionalCommand("taplo", Builtins.taplo)
  ["taplo-format"] = Base.optionalCommand("taplo", Builtins.taplo_format)
}

hooks = Base.defaultHooks(true, (Base.baseSteps) {
  ...Python.pythonSteps
  ...repoSteps
})
```

## Release workflow

This repo uses Cocogitto plus an explicit release script:

1. Create normal changes with conventional commits.
2. Run `scripts/release.sh X.Y.Z`.
3. The script renders the unreleased range with `cog changelog`, updates and stages `CHANGELOG.md`, creates the signed `release: vX.Y.Z` commit, and creates the matching `vX.Y.Z` tag.
4. Push `main` and the tag; `.github/workflows/release.yml` packages the Pkl modules, generates GitHub Artifact Attestations for the release assets, and creates the immutable GitHub Release with notes and pinned package examples.

Downstream repos should pin imports to release packages, for example:

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/vX.Y.Z/hk-config@X.Y.Z#/Base.pkl"
```

## Install hooks

Recommended on Git 2.54+:

```sh
hk install --global --mise
```

After that, adding a committed `hk.pkl` to a repo is enough. Repos without an `hk.pkl` are no-ops.

For per-repo install instead:

```sh
hk install --mise
```

## Validate this repo

```sh
hk validate
hk check --all --check
tmp=$(mktemp -d)
HK_CONFIG_VERSION=0.0.0 pkl project package --skip-publish-check --output-path "$tmp" .
rm -rf "$tmp"
```
