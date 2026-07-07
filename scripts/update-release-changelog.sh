#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 COMMIT_MSG_FILE" >&2
	exit 2
fi

commit_msg_file=$1
subject=$(awk '
  /^[[:space:]]*#/ { next }
  /^[[:space:]]*$/ { next }
  { print; exit }
' "$commit_msg_file")

if [[ $subject != release:* ]]; then
	exit 0
fi

if [[ ! $subject =~ ^release:\ (v[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
	echo "release commits must use: release: vX.Y.Z" >&2
	exit 1
fi

tag=${BASH_REMATCH[1]}
version=${tag#v}

if ! command -v cog >/dev/null 2>&1; then
	echo "release changelog generation requires cog on PATH" >&2
	exit 1
fi

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
	echo "release changelog generation requires an existing HEAD commit" >&2
	exit 1
fi

if ! git ls-files --error-unmatch CHANGELOG.md >/dev/null 2>&1; then
	echo "CHANGELOG.md must be tracked before creating a release" >&2
	exit 1
fi

if ! git diff --quiet -- CHANGELOG.md || ! git diff --cached --quiet -- CHANGELOG.md; then
	echo "CHANGELOG.md has pending changes; let the release hook update it from a clean state" >&2
	exit 1
fi

if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
	echo "tag $tag already exists; release commits must create a new tag" >&2
	exit 1
fi

if grep -q "^## \[$tag\]" CHANGELOG.md; then
	echo "CHANGELOG.md already contains a section for $tag" >&2
	exit 1
fi

if ! cog verify --file "$commit_msg_file" >/dev/null 2>&1; then
	cog verify --file "$commit_msg_file"
	exit 1
fi

previous_tag=$(cog -v get-version --tag 2>/dev/null || true)
if [[ -n $previous_tag ]]; then
	release_block=$(cog changelog "$previous_tag..HEAD")
else
	release_block=$(cog changelog)
fi
if [[ -z ${release_block//[[:space:]]/} ]]; then
	echo "cog generated an empty changelog for $tag" >&2
	exit 1
fi

repository_url=$(printf '%s\n' "$release_block" | sed -nE '1s|^## Unreleased \(\[[^]]+\]\((.*)/compare/.*\)\)$|\1|p')
release_date=$(date +%F)

if [[ -n $repository_url && -n $previous_tag ]]; then
	release_heading="## [$tag]($repository_url/compare/$previous_tag..$tag) - $release_date"
elif [[ -n $repository_url ]]; then
	release_heading="## [$tag]($repository_url/releases/tag/$tag) - $release_date"
else
	release_heading="## [$tag] - $release_date"
fi

release_body=$(printf '%s\n' "$release_block" | tail -n +2)
release_block="$release_heading"$'\n'"$release_body"

tmp=$(mktemp)
inserted=0
while IFS= read -r line || [[ -n $line ]]; do
	printf '%s\n' "$line" >>"$tmp"
	if [[ $inserted -eq 0 && $line == "- - -" ]]; then
		printf '%s\n\n- - -\n' "$release_block" >>"$tmp"
		inserted=1
	fi
done <CHANGELOG.md

if [[ $inserted -eq 0 ]]; then
	rm -f "$tmp"
	echo "CHANGELOG.md must contain Cocogitto separator: - - -" >&2
	exit 1
fi

mv "$tmp" CHANGELOG.md
git add CHANGELOG.md

echo "updated CHANGELOG.md for $tag ($version)"
