#!/usr/bin/env bash
set -euo pipefail

subject=$(git log -1 --format=%s)

if [[ $subject != release:* ]]; then
	exit 0
fi

if [[ ! $subject =~ ^release:\ (v[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
	echo "release commits must use: release: vX.Y.Z" >&2
	exit 1
fi

tag=${BASH_REMATCH[1]}
head_oid=$(git rev-parse HEAD)

if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
	tag_oid=$(git rev-list -n 1 "$tag")
	if [[ $tag_oid == "$head_oid" ]]; then
		exit 0
	fi

	echo "tag $tag already exists but does not point at HEAD" >&2
	exit 1
fi

git tag "$tag"
echo "created release tag $tag"
