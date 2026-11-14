#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sources=(
    Sources Plugins Tests/SnaglessTests
    Examples/PluginDemo/Sources Examples/XcodeDemo/XcodeDemo Examples/Shop/Sources
    RuntimeCases/RuntimeCases
)
manifests=(Package.swift Examples/PluginDemo/Package.swift Examples/Shop/Package.swift)
case "${1:-lint}" in
lint)
    swift format lint --strict --recursive "${sources[@]}"
    swiftlint lint --strict --quiet "${sources[@]}" "${manifests[@]}"
    trailing=$(perl -0ne 'print "$ARGV\n" if /,\s*\)/' "${manifests[@]}")
    if [ -n "$trailing" ]; then
        echo "$trailing"
        echo "Remove the trailing comma before a closing parenthesis in these manifests, for Swift 6.0."
        exit 1
    fi
    ;;
format)
    swift format format --in-place --recursive "${sources[@]}"
    ;;
*)
    echo "usage: Scripts/lint.sh [lint|format]" >&2
    exit 2
    ;;
esac
