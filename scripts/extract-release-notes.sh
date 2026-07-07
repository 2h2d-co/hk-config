#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 vX.Y.Z" >&2
	exit 2
fi

tag=$1

if [[ ! $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "release tag must match vX.Y.Z" >&2
	exit 1
fi

awk -v tag="$tag" '
  $0 ~ "^## \\[" tag "\\]" { found = 1; print; next }
  found && $0 == "- - -" { exit }
  found { print }
  END { if (!found) exit 1 }
' CHANGELOG.md
