#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

device=${DEVICE:-booted}
bundle=dev.snagless.runtime-cases
seconds=${SECONDS_PER_CASE:-10}
output=$(mktemp -d)
trap 'rm -rf "$output"' EXIT

xcodegen generate --quiet
build=(-project RuntimeCases.xcodeproj -scheme RuntimeCases -destination 'generic/platform=iOS Simulator')
xcodebuild "${build[@]}" -quiet build
products=$(
    xcodebuild "${build[@]}" -showBuildSettings \
        | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2}'
)
xcrun simctl install "$device" "$products/RuntimeCases.app"

launch() {
    local log=$1
    shift
    xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
    xcrun simctl launch --console-pty "$device" "$bundle" "$@" >"$log" 2>&1 &
    local launcher=$!
    (sleep "$seconds" && kill "$launcher" 2>/dev/null) &
    local deadline=$!
    wait "$launcher" || true
    {
        kill "$deadline" && wait "$deadline"
    } 2>/dev/null || true
}

launch "$output/list" -list YES
cases=$(tr -d '\r' <"$output/list" | grep -E '^[a-zA-Z]+$')

differences=0
for name in ${*:-$cases}; do
    launch "$output/$name" -case "$name"
    crash=$(tr -d '\r' <"$output/$name" | grep -m1 -o 'Fatal error: .*' || true)
    if [ -n "$crash" ]; then
        result=crashed
    elif grep -q 'runtime-case: rendered' "$output/$name"; then
        result=rendered
    else
        result="no result"
    fi
    expected=$(awk -F'\t' -v name="$name" '$1 == name { print $2 }' expected.tsv)
    printf '%s\t%s\t%s\n' "$name" "$result" "$crash"
    if [ "$result" != "$expected" ]; then
        printf '    expected %s in expected.tsv\n' "${expected:-a row}"
        differences=$((differences + 1))
    fi
done
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
if [ "$differences" -gt 0 ]; then
    echo "$differences case(s) differ from expected.tsv"
    exit 1
fi
