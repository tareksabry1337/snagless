# Roadmap

Planned fixes, in order, each with the defect it fixes. Only defects go on this list, and a missed crash ranks
above a false positive.

Every step has to keep the tests passing, the generated apps (exactly the added crashes reported) and the
IceCubesApp triage (39 findings, 212 of 212 views reachable, every injection resolved) the same, or change them
only where the step says it will. A step that changes what Snagless believes about SwiftUI also needs a case in
RuntimeCases that shows the behaviour on a simulator, kept so it can be run again.

## 1. Hosting inside a representable

A representable that adds a `UIHostingController` as a child view controller passes the environment through
(RuntimeCases `hostingControllerAddedAsChild` renders), and so does a `UIHostingConfiguration` cell in a collection
view the representable makes (`hostingConfigurationCell` renders). Snagless treats both as fresh roots and reports
their requirements. Plan: treat hosting that a representable or its coordinator creates as part of the
representable, the way a controller returned from the maker already is.

## 2. Values provided inside a closure

`Reader().apply { $0.environment(Model()) }`, where `apply` is the app's own `View` extension that calls the
closure with `self`, renders (RuntimeCases `closureHelper`). Snagless skips values provided to `$0` inside a
closure argument, so it reports a missing `Model`. Plan: when a view extension applies a closure argument to
`self`, count what the closure provides, and only when every path through the extension applies it. A helper like
`.if(flag) { $0.environment(Model()) }` then stays reported, which is right: with the flag off it crashes
(`conditionalModifierFalse`).

## 3. Typealiases

`typealias Basket = Cart` and `.environment(Basket())` reports a missing `Cart`. Plan: collect typealiases in pass 1
and resolve them in pass 2 with the same import rules as types.

## 4. Generic helpers

`func inject<T>(_ value: T) -> some View { environment(value) }` hides the provided type from Snagless, so
`CartBadge().inject(Cart())` reports a missing `Cart`. Plan: record that the helper provides the type of its
argument and resolve it at each call.

## 5. How much was checked

Views kept in a dictionary of `AnyView` closures and looked up at runtime stay unreachable, so their requirements
go unchecked, and only `--verbose` mentions them. Plan: put the number of unreachable views with requirements on
the summary line, so a clean run says how much it covered.

## 6. Sheets and the deployment target

`--legacy-sheets` has to be passed by hand. Developers report that sheets inherit the environment reliably from
iOS 15 on. Plan: read the deployment target from `Package.swift` (`platforms:`) or the project file and turn the
flag on below iOS 15, with the flag kept as an override.

## 7. Binary frameworks and macros

Views and values inside binary frameworks and macro expansions are invisible to Snagless. Plan: read public
signatures from `.swiftinterface` files, and expand macros. Until then `// snagless: provides` covers the values.

## After the first release

### Values provided inside #if

A value provided only inside an `#if` block counts as provided in every build, so a crash in a build where the
block is left out goes unreported. RuntimeCases `postfixIfOtherPlatform` crashes and Snagless stays quiet; it is
the only crash in RuntimeCases that Snagless misses. Plan: in pass 1, work out which branches are active for each
build (Debug and Release on each of the target's platforms) and summarize each distinct set of branches; in pass
2, check each one. An unknown condition gives a note.
