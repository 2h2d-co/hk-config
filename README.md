# hk-config

Shared [hk](https://hk.jdx.dev/) configuration for 2h2d repositories.

These configs are committed Pkl library modules that project repos import. They are different from `~/.config/hk/config.pkl`: this repo is for team-shared policy, not per-user preferences.

## Files

- `Base.pkl` — general hygiene, secret-safety, and conventional commit step mappings.
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

Every project `hk.pkl` amends hk's version-matched `Config.pkl` directly. The modules in this package are regular, data-only Pkl libraries: `Base.pkl` exports shared step mappings, while stack-specific modules export additional step mappings. Project configs import the required mappings, spread them into one steps map, and assign that map to their hooks.

Keeping library modules separate from the amended hk configuration is required by current Pkl semantics. Keeping them data-only also avoids partial-import function evaluation issues in the Pkl runtime bundled with hk 1.50.0.

## Conditional external tools

hk conditions are `expr` strings. These configs use `step_condition` in two ways:

- command-optional steps use a `step_condition` expression and skip when the executable is not on `PATH`.
- project-file-conditioned steps use a `step_condition` expression and run when the repository contains the marker file.

The base config runs `gitleaks` opportunistically when installed. When `mise.toml` exists, `mise-installed` checks that `mise` is available on every hook run, and the `mise` formatter runs when mise config files are in the hook's file set.

## Commit messages

`Base.pkl` provides the steps used by the `commit-msg` hook. If `cog` is available, it uses hk's `cocogitto-commit-msg` builtin and Cocogitto validates according to the repo's `cog.toml`. If `cog` is not available, it falls back to hk's `check-conventional-commit` utility with the standard Conventional Commit types plus `release`.

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
- The Oxfmt step passes `--no-error-on-unmatched-pattern`, allowing project-level Oxfmt ignore rules to filter every selected file without failing the hook.

## Use from a repo

Use the Pkl package artifact published with each release. The Git tag includes the `v` prefix, while the Pkl package version does not:

```text
package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1
```

Every project amends hk's `Config.pkl` directly, imports the library modules it needs, and assembles its hooks:

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.50.0/hk@1.50.0#/Config.pkl"

import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1#/Base.pkl" as Base
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1#/Python.pkl" as Python
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1#/TypeScript.pkl" as TypeScript
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1#/Go.pkl" as Go
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1#/GitHubActions.pkl" as GitHubActions
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1#/Shell.pkl" as Shell

display_skip_reasons = Base.displaySkipReasons

local projectSteps = (Base.baseSteps) {
  ...Python.pythonSteps
  ...TypeScript.typeScriptSteps
  ...Go.goSteps
  ...GitHubActions.gitHubActionsSteps
  ...Shell.shellSteps
}

hooks = new Mapping<String, Hook> {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = projectSteps
  }
  ["pre-push"] {
    steps = projectSteps
  }
  ["commit-msg"] {
    steps = Base.commitMessageSteps
  }
  ["fix"] {
    fix = true
    steps = projectSteps
  }
  ["check"] {
    steps = projectSteps
  }
}
```

Import only the stack modules the project uses. For base-only configuration, import only `Base.pkl` and assign `Base.baseSteps` to the project hooks.

### Add repo-local steps

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.50.0/hk@1.50.0#/Config.pkl"

import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1#/Base.pkl" as Base
import "package://github.com/2h2d-co/hk-config/releases/download/v0.1.1/hk-config@0.1.1#/Python.pkl" as Python
import "package://github.com/jdx/hk/releases/download/v1.50.0/hk@1.50.0#/Builtins.pkl"

local repoSteps = new Mapping<String, Step> {
  ["taplo"] = (Builtins.taplo) {
    step_condition = "exec('command -v taplo >/dev/null 2>&1; echo $?') == '0\n'"
  }
  ["taplo-format"] = (Builtins.taplo_format) {
    step_condition = "exec('command -v taplo >/dev/null 2>&1; echo $?') == '0\n'"
  }
}

local projectSteps = (Base.baseSteps) {
  ...Python.pythonSteps
  ...repoSteps
}

display_skip_reasons = Base.displaySkipReasons
hooks = new Mapping<String, Hook> {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = projectSteps
  }
  ["pre-push"] {
    steps = projectSteps
  }
  ["commit-msg"] {
    steps = Base.commitMessageSteps
  }
  ["fix"] {
    fix = true
    steps = projectSteps
  }
  ["check"] {
    steps = projectSteps
  }
}
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
