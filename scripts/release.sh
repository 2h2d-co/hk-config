#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 X.Y.Z" >&2
	exit 2
fi

version=$1
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "release version must match X.Y.Z" >&2
	exit 1
fi

tag="v$version"

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
	echo "release requires an existing HEAD commit" >&2
	exit 1
fi

if [[ -n $(git status --porcelain=v1) ]]; then
	echo "working tree must be clean before creating a release" >&2
	exit 1
fi

if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
	echo "tag $tag already exists" >&2
	exit 1
fi

if git remote get-url origin >/dev/null 2>&1 && git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
	echo "remote tag $tag already exists" >&2
	exit 1
fi

msg=$(mktemp)
trap 'rm -f "$msg"' EXIT
printf 'release: %s\n' "$tag" >"$msg"

scripts/update-release-changelog.sh "$msg"

git commit -S -m "release: $tag"
git tag "$tag"

if [[ $(git cat-file -t "refs/tags/$tag") != commit ]]; then
	echo "release tag $tag must be a lightweight tag" >&2
	exit 1
fi

echo "created release commit and lightweight tag $tag"
echo "push with: git push origin main $tag"
