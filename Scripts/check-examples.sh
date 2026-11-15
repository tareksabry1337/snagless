#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
derived_data=$HOME/Library/Developer/Xcode/DerivedData

clean_up() {
    for folder in "$derived_data"/XcodeDemo-*; do
        if grep -qs "$work" "$folder/info.plist"; then
            rm -rf "$folder"
        fi
    done
    rm -rf "$work"
}
trap clean_up EXIT
copy=$work/snagless
rsync -a --exclude .build --exclude .git --exclude realapps --exclude generated --exclude RuntimeCases \
    --exclude '*.xcodeproj' "$repo/" "$copy/"
examples=$copy/Examples
profile=$examples/PluginDemo/Sources/Profile/ProfileBadge.swift
cart=$examples/Shop/Sources/Shop/CartBadge.swift
log=$work/build.log

show_errors() {
    grep -E "error:" "$log" | head -5 || tail -20 "$log"
}

build_package() {
    swift build --package-path "$examples/PluginDemo" >"$log" 2>&1
}

build_project() {
    xcodebuild -project "$examples/XcodeDemo/XcodeDemo.xcodeproj" -scheme XcodeDemo -destination 'platform=macOS' \
        -skipPackagePluginValidation build >"$log" 2>&1
}

expect_pass() {
    local step=$1
    local build=$2
    if ! "$build"; then
        show_errors
        echo "FAIL $step: expected the build to pass"
        exit 1
    fi
    echo "ok   $step: passes"
}

expect_missing() {
    local step=$1
    local build=$2
    local type=$3
    if "$build" || ! grep -q "without \`$type\`" "$log"; then
        show_errors
        echo "FAIL $step: expected the build to fail on the missing \`$type\`"
        exit 1
    fi
    echo "ok   $step: fails on the missing \`$type\`"
}

expect_cart_missing() {
    local step=$1
    local build=$2
    local location=$3
    expect_missing "$step" "$build" Cart
    local error="$location: error: \`ContentView\` is shown from App \`DemoApp\` without \`Cart\`; required by"
    error+=" ContentView → CartBadge (.*/Examples/Shop/Sources/Shop/CartBadge.swift:12)"
    if ! grep -q "$error" "$log"; then
        show_errors
        echo "FAIL $step: expected the missing \`Cart\` reported at $location"
        exit 1
    fi
    if grep -q "without \`Session\`" "$log"; then
        echo "FAIL $step: expected \`Session\` to count as provided"
        exit 1
    fi
}

require_new_type() {
    local file=$1
    local type=$2
    cp "$file" "$file.original"
    perl -0pi -e "s/(private var \\w+\\n)/\$1    \\@Environment($type.self)\\n    private var added\\n/" "$file"
    printf '\n@Observable\npublic final class %s {\n    public init() {}\n}\n' "$type" >>"$file"
}

restore() {
    mv "$1.original" "$1"
}

check() {
    local name=$1
    local build=$2
    expect_cart_missing "$name, as shipped" "$build" "$3"
    perl -pi -e 's/CartBadge\(\)$/CartBadge().environment(Cart())/' "$examples/$4"
    expect_pass "$name, Cart provided" "$build"
    require_new_type "$profile" Badge
    expect_missing "$name, missing value in another target" "$build" Badge
    restore "$profile"
    expect_pass "$name, other target fixed" "$build"
    require_new_type "$cart" Coupon
    expect_missing "$name, missing value in a local package" "$build" Coupon
    restore "$cart"
    expect_pass "$name, local package fixed" "$build"
}

check "package" build_package DemoApp.swift:9:13 PluginDemo/Sources/DemoApp/ContentView.swift
(cd "$examples/XcodeDemo" && xcodegen generate --quiet)
check "Xcode project" build_project DemoApp.swift:18:13 XcodeDemo/XcodeDemo/DemoApp.swift
