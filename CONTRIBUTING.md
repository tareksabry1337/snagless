# Contributing

## Reporting a wrong result

A false positive or a missed error is the most useful report. Include the smallest source that shows it (often two
or three views), the command you ran, and the output. For private code, `--verbose` output with names changed
helps too.

## How the code is laid out

The checker is four modules, and each one may only use the ones listed before it:

- `SnaglessModel` holds the summary types that pass 1 writes and pass 2 reads (`FileSummary` and everything in it),
  and `Workers`, which both passes use to spread work across threads with large stacks.
- `SnaglessSyntax` is pass 1. `Summarizer` reads each file on its own into a `FileSummary`. `PackageManifest` reads
  a `Package.swift` as text. It is the only module that uses SwiftSyntax.
- `SnaglessAnalysis` is pass 2. It resolves type names across all files (`TypeResolver`, `FileReferenceResolver`),
  links views into a graph (`NodeIndex`, `EdgeLinker`), works out what each view needs (`Needs`) and reports
  (`DiagnosticReport`, `Report`).
- `SnaglessDriver` is the command line: options, file listing (folders, `--package` packages and the target graph
  the plugin writes) and summarizing the files in parallel.

`Sources/snagless` only calls the driver. Types shared between modules use `package` access, so tests import the
modules directly.

The plugin in `Plugins/SnaglessPlugin` builds on its own, apart from these modules. It compiles the target graph
format itself through a symbolic link to `Sources/SnaglessDriver/TargetGraph.swift`, so the plugin writes and the
driver reads one definition. That file must stay plain, import-free Swift. The plugin also keeps its own list of
directories to skip, and `SourceRulesTests` checks that it matches the driver's.

The plugin talks to the tool through two internal options. `--targets FILE` reads the target graph: each target's
module name and exact Swift files. `--stamp FILE` writes an empty file after a clean run and deletes it after a
failed one, so Xcode has an output to track. In an Xcode project the plugin also passes the project folder and a
`--package` for every local package the project file lists, because Xcode tells build plugins only about each
target's own files.

## Before you send a change

- Add a test that only passes with the change. Tests build their sources inline and check the exact reported lines;
  pick the suite that matches what the change is about (`InjectionTests`, `MemberChainTests`, `InjectedValueTests`,
  `ViewFollowingTests` and so on).
- Run `Scripts/lint.sh format`, then `Scripts/lint.sh`. The second one fails on any formatting difference
  (`swift format`, settings in `.swift-format`) and on any SwiftLint finding (settings in `.swiftlint.yml`). It
  needs SwiftLint installed (`brew install swiftlint`).
- Run `swift test -Xswiftc -warnings-as-errors`. Besides the tests for each rule, it generates apps with crashes
  added at random and checks that exactly those are found, checks that output is the same in any file order, and
  checks the sources for calls that crash on purpose (`fatalError`, `precondition` and similar),
  top-level functions and variables, and a few banned words in names. The generated apps need `python3`.
- Fix every warning. Every target is built in Swift 6 language mode, and CI treats warnings as errors with the flag
  above.
- Keep the manifests (`Package.swift` and the examples') free of trailing commas before a closing parenthesis, so
  Swift 6.0 can read them. `Scripts/lint.sh` checks for them.
- If the change is about how SwiftUI behaves, add a case to RuntimeCases, an app with one case per behaviour, and
  a row to `RuntimeCases/expected.tsv` saying whether it crashes and whether Snagless reports it. Then run it:
  `RuntimeCases/run.sh [case...]` builds the app (it needs xcodegen), runs each case on a booted simulator (or the
  one in `DEVICE`), prints whether it rendered or crashed, and fails when a result differs from the table.
  `RuntimeCasesTests` checks the Snagless column on every test run.
- Keep the IceCubesApp results the same unless the change means to change them. Clone
  https://github.com/Dimillian/IceCubesApp at commit 98098b9 into `realapps/`, run a release build of the previous
  commit and of your change on it, and compare the output. It reports 39 errors, 86 with `--legacy-sheets` and 2
  with `--previews off`.
- If the change could affect speed, time a release build before and after with
  `Scripts/bench.py --binary .build/release/snagless FOLDER...`. It prints the median of seven runs of each step for
  every folder; the speed numbers in the README come from it.

CI runs the lint, the tests and `Scripts/check-examples.sh`. The script builds both example projects, which leave
out `Cart` on purpose and must fail on it, then adds a missing value in another target and in a local package, and
checks that Snagless runs again and fails each time, then passes once it is fixed. It needs xcodegen.

CI builds the Xcode example with Xcode 27.0, which writes the classic `project.pbxproj`. To check the JSON project
file (`project.xcproj`) that Xcode 27.2 writes, convert a copy of the example with
`xcodebuild -convert-project xcproj` and build it; it must report the same error.

A new rule goes in only with a real case behind it. ROADMAP.md lists the planned work, each item with the defect
it fixes.
