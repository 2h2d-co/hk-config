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

if [[ $(git branch --show-current) != main ]]; then
	echo "releases must be created from main" >&2
	exit 1
fi

if [[ -n $(git status --porcelain=v1) ]]; then
	echo "working tree must be clean before creating a release" >&2
	exit 1
fi

git fetch --quiet --tags origin main
if [[ $(git rev-parse HEAD) != "$(git rev-parse origin/main)" ]]; then
	echo "HEAD must match origin/main before creating a release" >&2
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

tmpdir=$(mktemp -d)
trap 'rm -f "$msg"; rm -rf "$tmpdir"' EXIT
pkl_bin=$(mise which pkl)

build_from_index() {
	local destination=$1
	local source=$tmpdir/source
	rm -rf "$source"
	mkdir -p "$source"
	git checkout-index --all --force --prefix="$source/"
	(
		cd "$source"
		PKL_BIN=$pkl_bin scripts/package-release.sh "$version" "$destination"
	)
}

local_output=$tmpdir/local
local_digest=$(build_from_index "$local_output")

git commit -S \
	-m "release: $tag" \
	-m "Release-Manifest-SHA256: $local_digest"

release_commit=$(git rev-parse HEAD)
git -c gpg.format=ssh \
	-c gpg.ssh.allowedSignersFile=.github/release-signers \
	verify-commit "$release_commit"
signed_digest=$(git log -1 \
	--format='%(trailers:key=Release-Manifest-SHA256,valueonly)' \
	"$release_commit")
if [[ $signed_digest != "$local_digest" ]]; then
	echo "signed release manifest digest does not match the local artifacts" >&2
	exit 1
fi

committed_output=$tmpdir/committed
committed_digest=$(build_from_index "$committed_output")
if [[ $committed_digest != "$local_digest" ]]; then
	echo "Pkl release artifacts are not reproducible" >&2
	exit 1
fi

git tag "$tag"

if [[ $(git cat-file -t "refs/tags/$tag") != commit ]]; then
	echo "release tag $tag must be a lightweight tag" >&2
	exit 1
fi

echo "created signed release commit $release_commit"
echo "created lightweight tag $tag"
echo "locally attested release manifest SHA-256: $local_digest"
echo "push with: git push --atomic origin main $tag"
