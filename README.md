# hk-config

Shared [hk](https://hk.jdx.dev/) configuration for 2h2d repositories.

These configs are committed Pkl library modules that project repos import. They are different from `~/.config/hk/config.pkl`: this repo is for team-shared policy, not per-user preferences.

## Files

- `Base.pkl` — general hygiene, secret-safety, and conventional commit step mappings.
- `Config.pkl` — the shared amended hk schema and minimum hk version.
- `Python.pkl` — Python syntax/debug and optional Ruff steps.
- `TypeScript.pkl` — optional Oxfmt, Oxlint, and TypeScript steps.
- `Go.pkl` — optional Go formatting, module, vet, vulnerability, and golangci-lint steps.
- `GitHubActions.pkl` — optional GitHub Actions linting and security steps.
- `Shell.pkl` — optional shfmt and ShellCheck steps for `.sh`/`.bash` files.
- `PklProject` — Pkl package metadata for release artifacts.
- `cog.toml` and `CHANGELOG.md` — Cocogitto release/changelog configuration for this repo.
- `AGENTS.md` — repository conventions for coding agents and humans.
- `LICENSE` — MIT license for this repo.

## Architecture

Every project `hk.pkl` amends this package's `Config.pkl`, which amends hk's version-matched schema and sets `min_hk_version`. The remaining modules are regular Pkl libraries: `Base.pkl` exports shared helpers and step mappings, while stack-specific modules export additional step mappings. Project configs import the required mappings, spread them into one steps map, and pass that map to `Base.defaultHooks(...)`.

Keeping library modules separate from the amended hk configuration is required by current Pkl semantics. hk 1.56.0 correctly evaluates sibling helper functions in partially imported modules.

## Conditional external tools

hk conditions are `expr` strings. These configs use `step_condition` in two ways:

- command-optional steps use `Base.optionalCommand(...)` and skip when the executable is not on `PATH`.
- project-file-conditioned steps use `Base.whenFileExists(...)` and run when the repository contains the marker file.

The base config runs `betterleaks` opportunistically when installed and passes each hk batch's selected files to one multi-path scan. Betterleaks scopes the scan to those paths while avoiding a separate scanner process for every file. When `mise.toml` exists, `mise-installed` checks that `mise` is available on every hook run, and the `mise` formatter runs when mise config files are in the hook's file set.

The Go vulnerability step verifies the exact `golang.org/x/vuln/cmd/govulncheck` tool declaration, then runs `go tool govulncheck ./...` from each module workspace. It watches Go source plus `go.mod` and `go.sum`, so dependency-only changes are scanned. Go projects that import `Go.pkl` must declare govulncheck as a Go tool dependency so its version and checksums remain in `go.mod` and `go.sum`.

## Commit messages

`Base.pkl` provides the steps used by the `commit-msg` hook. It rejects literal escape sequences before the commit is created. Literal `\n` sequences receive specific guidance to use multiple `-m` arguments or ANSI-C shell quoting (`$'...\n...'`) for newlines; other backslash escape sequences receive a general validation error.

If `cog` is available, the hook also uses hk's `cocogitto-commit-msg` builtin and Cocogitto validates according to the repo's `cog.toml`. If `cog` is not available, it falls back to hk's `check-conventional-commit` utility with the standard Conventional Commit types plus `release`.

Allowed types for the fallback hk utility path:

```text
build,chore,ci,docs,feat,fix,perf,refactor,revert,style,test,release
```

If a repo uses Cocogitto and wants `release: ...` commits, configure Cocogitto to allow that custom type in `cog.toml`. This repo's `cog.toml` allows `release: vX.Y.Z` commits and sets `tag_prefix = "v"` so release tags are `vX.Y.Z`.

Release tags must be lightweight tags. Create one with `git tag vX.Y.Z`; do not use `git tag -a`, `git tag -s`, `git tag -m`, or `cog bump --annotated`. The shared pre-commit hook rejects a release tag on `HEAD` when it is annotated or signed, and the pre-push hook rejects an annotated or signed release tag before it reaches a remote.

## Tool-specific vs generic config checks

Prefer domain-specific tools when they exist, then add generic formatters only for files without a better owner:

- `mise fmt` understands mise config locations and intended formatting. Use TOML tools such as `taplo` or `tombi` for general TOML files, not as a replacement for the mise step.
- `actionlint` and `zizmor` understand GitHub Actions semantics. The shared zizmor step uses its pedantic persona and audits suppressed findings with `--no-ignores`. Generic YAML tools can be useful in a future `Yaml.pkl`, but they do not replace Actions-specific checks.
- `hk validate` checks hk config semantics after Pkl evaluation. `pkl_format` is useful for formatting Pkl source, and `pkl eval` checks generic Pkl evaluation, but neither is a substitute for `hk validate` on hk config files.
- Avoid two generic formatters owning the same file unless their output is stable together; if multiple fixers touch the same files, order them with `depends`.
- The Oxfmt step passes `--no-error-on-unmatched-pattern`, allowing project-level Oxfmt ignore rules to filter every selected file without failing the hook.

## Use from a repo

Use the Pkl package artifact published with each release. The Git tag includes the `v` prefix, while the Pkl package version does not:

```text
package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0
```

Every project amends this package's `Config.pkl`, imports the library modules it needs from the same package version, and assembles its hooks:

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/Config.pkl"

import "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/Base.pkl" as Base
import "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/Python.pkl" as Python
import "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/TypeScript.pkl" as TypeScript
import "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/Go.pkl" as Go
import "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/GitHubActions.pkl" as GitHubActions
import "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/Shell.pkl" as Shell

display_skip_reasons = Base.displaySkipReasons

local projectSteps = (Base.baseSteps) {
  ...Python.pythonSteps
  ...TypeScript.typeScriptSteps
  ...Go.goSteps
  ...GitHubActions.gitHubActionsSteps
  ...Shell.shellSteps
}

hooks = Base.defaultHooks(true, projectSteps)
```

Import only the stack modules the project uses. For base-only configuration, import only `Base.pkl` and pass `Base.baseSteps` to `Base.defaultHooks(...)`.

### Add repo-local steps

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/Config.pkl"

import "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/Base.pkl" as Base
import "package://github.com/2h2d-co/hk-config/releases/download/v0.8.0/hk-config@0.8.0#/Python.pkl" as Python
import "package://github.com/jdx/hk/releases/download/v1.56.0/hk@1.56.0#/Builtins.pkl"

local repoSteps = new Mapping<String, Step> {
  ["taplo"] = Base.optionalCommand("taplo", Builtins.taplo)
  ["taplo-format"] = Base.optionalCommand("taplo", Builtins.taplo_format)
}

local projectSteps = (Base.baseSteps) {
  ...Python.pythonSteps
  ...repoSteps
}

display_skip_reasons = Base.displaySkipReasons
hooks = Base.defaultHooks(true, projectSteps)
```

## Release workflow

This repo uses Cocogitto plus an explicit release script:

1. Create normal changes with conventional commits.
2. Run `scripts/release.sh X.Y.Z`.
3. The script renders the unreleased range with `cog changelog`, updates and stages `CHANGELOG.md`,
   reproducibly builds the Pkl assets, records their canonical manifest digest in the signed
   `release: vX.Y.Z` commit, rebuilds the committed tree, and creates the matching lightweight tag.
4. Push `main` and the tag atomically with `git push --atomic origin main vX.Y.Z`. A read-only
   workflow job reproduces the signed assets; a separate credentialed job verifies, attests, and
   publishes those exact files with notes and pinned package examples.

Downstream repos should amend the shared config and pin imports to the same release package, for example:

```pkl
amends "package://github.com/2h2d-co/hk-config/releases/download/vX.Y.Z/hk-config@X.Y.Z#/Config.pkl"
import "package://github.com/2h2d-co/hk-config/releases/download/vX.Y.Z/hk-config@X.Y.Z#/Base.pkl" as Base
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
