#!/bin/bash
set -euo pipefail

version=${1:?usage: Scripts/release.sh VERSION}
repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"

linux_image=swift:6.4.3
linux_sdk_url=https://download.swift.org/swift-6.4.3-release/static-sdk/swift-6.4.3-RELEASE/swift-6.4.3-RELEASE_static-linux-0.1.0.artifactbundle.tar.gz
linux_sdk_checksum=529e6982974de78793c8348c1459105a772f54b464a51edf074e5b9c4bfe7c73
linux_arches=(x86_64 aarch64)

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

linux_work=$output/linux
mkdir -p "$linux_work"
curl -fsSL "$linux_sdk_url" -o "$linux_work/static-linux-sdk.tar.gz"
echo "$linux_sdk_checksum  $linux_work/static-linux-sdk.tar.gz" | shasum -a 256 -c -
docker run --rm \
    -v "$repo":/src:ro \
    -v snagless-release-build:/build \
    -v "$linux_work":/out \
    -e SNAGLESS_FROM_SOURCE=1 \
    -w /src \
    "$linux_image" \
    bash -euo pipefail -c "
        swift sdk install /out/static-linux-sdk.tar.gz
        for arch in ${linux_arches[*]}; do
            build=(swift build --scratch-path /build/\$arch -c release --product snagless --swift-sdk \$arch-swift-linux-musl)
            \"\${build[@]}\"
            mkdir -p /out/\$arch
            llvm-objcopy --strip-all \"\$(\"\${build[@]}\" --show-bin-path)/snagless\" /out/\$arch/snagless
        done
    "

for arch in "${linux_arches[@]}"; do
    platform=linux/$([ "$arch" = x86_64 ] && echo amd64 || echo arm64)
    linux_run=(docker run --rm --platform "$platform" -v "$linux_work/$arch":/out:ro -v "$repo/Examples":/examples:ro
        ubuntu:24.04 /out/snagless)
    reported=$("${linux_run[@]}" --version)
    if [ "$reported" != "snagless $version" ]; then
        echo "The $arch Linux binary reports \"$reported\"; expected \"snagless $version\"."
        exit 1
    fi
    status=0
    found=$("${linux_run[@]}" /examples 2>/dev/null) || status=$?
    if [ "$status" != 1 ] || ! grep -q 'needs `Cart`' <<<"$found"; then
        echo "The $arch Linux binary exited with $status on Examples; expected 1 and the missing \`Cart\`:"
        echo "$found"
        exit 1
    fi
    cp LICENSE NOTICE "$linux_work/$arch/"
    COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -czf "$output/snagless-linux-$arch.tar.gz" \
        -C "$linux_work/$arch" snagless LICENSE NOTICE
done

lipo -info "$bundle/$variant/bin/snagless"
for arch in "${linux_arches[@]}"; do
    file "$linux_work/$arch/snagless"
done
rm -rf "$linux_work"
for file in "$output"/*.zip "$output"/*.tar.gz; do
    echo "$file: $(stat -f %z "$file") bytes, sha256 $(shasum -a 256 "$file" | cut -d' ' -f1)"
done
echo "checksum for Package.swift: $checksum"
