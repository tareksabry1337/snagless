#!/bin/bash
set -euo pipefail

version=${1:?usage: Scripts/release.sh VERSION}
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"

build=(swift build -c release --arch arm64 --arch x86_64 --product snagless)
"${build[@]}"
binary=$("${build[@]}" --show-bin-path)/snagless

reported=$("$binary" --version)
if [ "$reported" != "snagless $version" ]; then
    echo "The binary reports \"$reported\"; expected \"snagless $version\". Update Snagless.version first."
    exit 1
fi

output=$repo/.build/release-bundle
bundle=$output/snagless.artifactbundle
variant=snagless-$version-macos
rm -rf "$output"
mkdir -p "$bundle/$variant/bin"
cp "$binary" "$bundle/$variant/bin/snagless"
cp LICENSE NOTICE "$bundle/"
cat >"$bundle/info.json" <<EOF
{
    "schemaVersion": "1.0",
    "artifacts": {
        "snagless": {
            "version": "$version",
            "type": "executable",
            "variants": [
                {
                    "path": "$variant/bin/snagless",
                    "supportedTriples": ["arm64-apple-macosx", "x86_64-apple-macosx"]
                }
            ]
        }
    }
}
EOF
(cd "$output" && zip -qry snagless.artifactbundle.zip snagless.artifactbundle)
archive=$output/snagless.artifactbundle.zip
checksum=$(swift package compute-checksum "$archive")

lipo -info "$bundle/$variant/bin/snagless"
echo "binary: $(stat -f %z "$bundle/$variant/bin/snagless") bytes, archive: $(stat -f %z "$archive") bytes"
echo "archive: $archive"
echo "checksum: $checksum"
