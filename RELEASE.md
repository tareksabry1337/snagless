# Releasing

## How the plugin gets its binary

`Package.swift` has one switch, `releasedBinary`. While it is `nil` the plugin builds Snagless from source, which
compiles swift-syntax. Once it holds the released bundle, the plugin uses the prebuilt binary and skips that
compile, which takes roughly 10 seconds off a clean build of each example project. Contributors who want the
source build anyway set `SNAGLESS_FROM_SOURCE=1`.

The bundle is macOS only: one universal binary for arm64 and x86_64. SwiftUI apps don't build on Linux, so the
plugin never runs there, and every plugin user downloads the whole bundle, so Linux binaries stay out of it. A
static Linux binary links in Foundation's ICU data and is about 60 MB; the bundle would grow from 8 MB to 55 MB.

## Linux binaries

Each release also has `snagless-linux-x86_64.tar.gz` and `snagless-linux-aarch64.tar.gz`, each holding the
`snagless` binary with the LICENSE and NOTICE. They are built with Swift's static Linux SDK, so they need no Swift
runtime or particular C library on the machine. The README's command line and GitHub Actions snippets download
them.

## Checklist

1. Set the version in `Snagless.version` (`Sources/SnaglessDriver/Snagless.swift`) and in the README's three
   snippets: Swift package, Command line and GitHub Actions.
2. Run the checks in CONTRIBUTING.md, including the IceCubesApp comparison.
3. Start Docker and run `Scripts/release.sh VERSION`. It builds the universal macOS binary, then the two Linux
   binaries in a `swift` container, and checks that each one prints `snagless VERSION` (the Linux ones in an
   Ubuntu container of their own architecture). It writes `snagless.artifactbundle.zip` and the two Linux archives
   to `.build/release-bundle`, and prints each binary's architecture, each archive's size and SHA-256, and the
   checksum for `Package.swift`. The Linux builds compile swift-syntax twice, so it takes a while. The container's
   Swift version and the static SDK at the top of the script have to match exactly; update all three lines
   together.
4. Point `releasedBinary` at the archive's release URL with the printed checksum:
   `.binaryTarget(name: "SnaglessBinary", url: "https://github.com/tareksabry1337/snagless/releases/download/VERSION/snagless.artifactbundle.zip", checksum: "CHECKSUM")`.
   The checksum covers only the archive, so it stays the same after this edit. Commit, and tag that commit with
   the version.
5. Create the GitHub release for the tag and upload the three archives, so the URL from step 4 and the README's
   snippets work.
6. In a new folder, make a package that depends on the tag and uses the plugin, build it, and check that
   the build uses the prebuilt binary. Then run the README's command line snippet in a fresh `ubuntu` container on
   one of the example folders and check that it reports the missing `Cart`.

## Toolchain

`Package.swift` declares `swift-tools-version: 6.0`, so Xcode 16 is the lowest version that can read it. Before
a release, run the checks with every Xcode on hand and update the compatibility table under Requirements in the
README.

## Planned for 1.0

### Homebrew

`brew install snagless` for the command line tool, on macOS and Linux, through homebrew-core. A core formula builds
from source, and homebrew-core takes a repository once it is 30 days old and has 75 stars, 30 forks or 30 watchers
(three times that when the owner submits it). If the repository qualifies by 1.0, submit the formula there. Until
it does, a tap repository with a formula that installs the binary from the release archive covers it, plus a
checklist step that updates the formula's version and checksum; the tap goes once homebrew-core takes the formula.
