#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
	echo "usage: $0 X.Y.Z OUTPUT_DIRECTORY" >&2
	exit 2
fi

version=$1
output=$2
pkl_bin=${PKL_BIN:-pkl}
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "release version must match X.Y.Z" >&2
	exit 1
fi

if [[ -e $output && -n $(find "$output" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
	echo "release output directory must be empty: $output" >&2
	exit 1
fi
mkdir -p "$output"
output=$(cd "$output" && pwd)

HK_CONFIG_VERSION=$version "$pkl_bin" project package --skip-publish-check --output-path "$output" . >&2

package="hk-config@$version"
assets=(
	"$package"
	"$package.sha256"
	"$package.zip"
	"$package.zip.sha256"
)
for asset in "${assets[@]}"; do
	if [[ ! -f "$output/$asset" ]]; then
		echo "missing Pkl release artifact: $asset" >&2
		exit 1
	fi
done

package_digest=$(shasum -a 256 "$output/$package" | awk '{print $1}')
zip_digest=$(shasum -a 256 "$output/$package.zip" | awk '{print $1}')
if [[ $(<"$output/$package.sha256") != "$package_digest" ]]; then
	echo "Pkl package checksum file does not match its artifact" >&2
	exit 1
fi
if [[ $(<"$output/$package.zip.sha256") != "$zip_digest" ]]; then
	echo "Pkl ZIP checksum file does not match its artifact" >&2
	exit 1
fi

(
	cd "$output"
	shasum -a 256 "${assets[@]}" >release-manifest.sha256
	shasum -a 256 -c release-manifest.sha256 >&2
)

shasum -a 256 "$output/release-manifest.sha256" | awk '{print $1}'
