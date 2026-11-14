# Releasing

## How the plugin gets its binary

`Package.swift` has one switch, `releasedBinary`. While it is `nil` the plugin builds Snagless from source, which
compiles swift-syntax. Once it holds the released bundle, the plugin uses the prebuilt binary and skips that
compile, which takes roughly 10 seconds off a clean build of each example project. Contributors who want the
source build anyway set `SNAGLESS_FROM_SOURCE=1`.

The bundle is macOS only: one universal binary for arm64 and x86_64. Linux binaries are on the roadmap for after
the first release.

## Checklist

1. Set the version in `Snagless.version` (`Sources/SnaglessDriver/Snagless.swift`) and in the README's install
   snippet.
2. Run the checks in CONTRIBUTING.md, including the IceCubesApp comparison.
3. Run `Scripts/release.sh VERSION`. It builds the universal binary in release, checks that `snagless --version`
   prints `snagless VERSION`, writes `.build/release-bundle/snagless.artifactbundle.zip` with the LICENSE and
   NOTICE inside, and prints the binary's architectures, its size and the archive's checksum. It takes a few
   minutes.
4. Point `releasedBinary` at the archive's release URL with the printed checksum:
   `.binaryTarget(name: "SnaglessBinary", url: "https://github.com/OWNER/snagless/releases/download/VERSION/snagless.artifactbundle.zip", checksum: "CHECKSUM")`.
   The checksum covers only the archive, so it stays the same after this edit. Commit, and tag that commit with
   the version.
5. Create the GitHub release for the tag and upload the archive, so the URL from step 4 works.
6. In a new folder, make a package that depends on the tag and uses the plugin, build it, and check that
   the build uses the prebuilt binary.

## Toolchain

`Package.swift` declares `swift-tools-version: 6.0`, so Xcode 16 is the lowest version that can read it. Before
a release, run the checks with every Xcode on hand and update the compatibility table under Requirements in the
README.
