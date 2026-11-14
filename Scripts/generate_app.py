#!/usr/bin/env python3
"""Generate a synthetic SwiftUI app with known missing-environment violations.

Ground truth is computed by simulating environment flow over the generated view
graph, independently of Snagless, and written to expected.json.
"""
import argparse
import json
import os
import random

MODELS = [f"Model{i}" for i in range(20)]
STORES = [f"Store{i}" for i in range(4)]
TYPES = MODELS + STORES
EXTENSION_TYPES = {f"Model{i}" for i in range(6)}
MODIFIER_TYPES = {f"Model{i}" for i in range(6, 10)}
PROPERTY_TYPES = {"Model10", "Model11"}
HATCH_TYPE = "Model12"
CORE_BUNDLE = {"Model0", "Model1", "Model6"}
ROOT_MARK = "\x00ROOT:"

INLINE_FORMS = ["direct", "direct", "init", "container", "navlink_closure", "navlink_destination",
                "foreach", "outside_sheet"]
PRESENTATION_FORMS = ["sheet", "popover", "fullScreenCover"]


def lower_first(name):
    return name[0].lower() + name[1:]


class Context:
    def __init__(self, kind):
        self.kind = kind
        self.properties = {}

    def property(self, type_name):
        name = lower_first(type_name)
        self.properties[name] = type_name
        return name

    def declarations(self, indent):
        pad = " " * indent
        lines = []
        for name, type_name in sorted(self.properties.items()):
            if self.kind == "view" or self.kind == "app":
                wrapper = "@StateObject" if type_name in STORES else "@State"
                lines.append(f"{pad}{wrapper} private var {name} = {type_name}()")
            elif self.kind == "host":
                lines.append(f"{pad}let {name} = {type_name}()")
            else:
                factory = "shared" if type_name in STORES else "preview()"
                lines.append(f"{pad}let {name} = {type_name}.{factory}")
        return lines


def injection_lines(types, ctx, rng):
    remaining = set(types)
    lines = []
    if CORE_BUNDLE <= remaining and rng.random() < 0.5:
        lines.append(".withCoreModels()")
        remaining -= CORE_BUNDLE
    can_use_self = ctx.kind in ("view", "app", "host")
    for t in sorted(remaining):
        if t in STORES:
            if rng.random() < 0.5:
                lines.append(f".environmentObject({t}.shared)")
            else:
                lines.append(f".environmentObject({ctx.property(t)})")
        elif t in EXTENSION_TYPES:
            lines.append(rng.choice([f".with{t}()", f".environment({t}.shared)"]))
        elif t in MODIFIER_TYPES:
            lines.append(rng.choice([f".modifier(Inject{t}())", f".environment({t}())"]))
        elif t in PROPERTY_TYPES:
            name = ctx.property(t)
            if can_use_self and rng.random() < 0.5:
                lines.append(f".environment(self.{name})")
            else:
                lines.append(f".environment({name})")
        elif t == HATCH_TYPE:
            lines.append(f".environment(make{t}()) // snagless: provides {t}")
        else:
            lines.append(rng.choice([f".environment({t}.preview())", f".environment({t}.shared)",
                                     f".environment({t}.init())"]))
    rng.shuffle(lines)
    if rng.random() < 0.2:
        lines.insert(rng.randrange(len(lines) + 1), ".environment(\\.colorScheme, .dark)")
    if rng.random() < 0.2:
        lines.insert(rng.randrange(len(lines) + 1), ".padding()")
    return lines


def indent(lines, amount):
    pad = " " * amount
    return [pad + line if line else line for line in lines]


class GeneratedApp:
    def __init__(self, n, seed, violations):
        self.n = n
        self.rng = random.Random(seed)
        self.seed = seed
        self.added_count = violations if violations is not None else max(5, n // 100)
        self.files = {}
        self.root_edges = {}

    def build_graph(self):
        rng = self.rng
        n = self.n
        hosting_count = max(2, n // 200)
        self.hosting_tops = sorted(rng.sample(range(1, n), hosting_count))
        tops = set([0] + self.hosting_tops)
        self.children = {i: [] for i in range(n)}
        for i in range(1, n):
            if i in tops:
                continue
            parents = {rng.randrange(0, i)}
            if rng.random() < 0.05 and i > 1:
                parents.add(rng.randrange(0, i))
            for p in parents:
                self.children[p].append(i)
        self.requires = {}
        self.optional = {}
        for i in range(n):
            count = rng.choices([0, 1, 2], weights=[4, 4, 2])[0]
            self.requires[i] = set(rng.sample(TYPES, count))
            if rng.random() < 0.1:
                self.optional[i] = rng.choice([t for t in MODELS if t not in self.requires[i]])
        self.generic = {i for i in range(1, n) if rng.random() < 0.05}

        self.edge_injection = {}
        self.needs = {}
        for v in range(n - 1, -1, -1):
            need = set(self.requires[v])
            for c in self.children[v]:
                passed = {t for t in self.needs[c] if rng.random() >= 0.3}
                self.edge_injection[(v, c)] = self.needs[c] - passed
                need |= passed
            self.needs[v] = need

        preview_count = max(5, n // 30)
        self.preview_views = sorted(rng.sample(range(n), preview_count))
        self.host_in_view = {}
        for h in self.hosting_tops:
            if rng.random() < 0.5:
                self.host_in_view[h] = rng.randrange(0, n)

        root_ids = [("app", 0)] + [("hosting", h) for h in self.hosting_tops] + \
                   [("preview", v) for v in self.preview_views]
        self.root_injection = {}
        for kind, top in root_ids:
            self.root_injection[(kind, top)] = set(self.needs[top])
        candidates = [r for r in root_ids if self.needs[r[1]] and r[0] != "app"]
        rng.shuffle(candidates)
        if self.needs[0]:
            candidates.insert(0, ("app", 0))
        self.added = []
        index = 0
        while len(self.added) < self.added_count and candidates:
            root = candidates[index % len(candidates)]
            index += 1
            available = sorted(self.root_injection[root])
            if not available:
                if index > 10 * len(candidates):
                    break
                continue
            t = rng.choice(available)
            self.root_injection[root].discard(t)
            self.added.append((root, t))
        self.root_ids = root_ids

    def type_name(self, v):
        return f"V{v}<Int>" if v in self.generic else f"V{v}"

    def view_path(self, v):
        return f"Views/G{v // 500}/V{v}.swift"

    def root_line(self, kind, top, ctx, indent_amount, prefix=""):
        name = self.type_name(top)
        mods = injection_lines(self.root_injection[(kind, top)], ctx, self.rng)
        first = f"{prefix}{name}(){ROOT_MARK}{kind}:{top}"
        return indent([first] + indent(mods, 4), indent_amount)

    def child_chunk(self, v, c, ctx, flags):
        rng = self.rng
        name = self.type_name(c)
        mods = injection_lines(self.edge_injection[(v, c)], ctx, rng)
        form = rng.choice(INLINE_FORMS + PRESENTATION_FORMS)
        if form == "direct":
            return "inline", [f"{name}()"] + indent(mods, 4)
        if form == "init":
            return "inline", [f"{name}.init()"] + indent(mods, 4)
        if form == "container":
            return "inline", ["Group {", f"    {name}()", "}"] + mods
        if form == "navlink_closure":
            return "inline", ["NavigationLink {", f"    {name}()"] + indent(mods, 8) + \
                ["} label: {", '    Text("Open")', "}"]
        if form == "navlink_destination":
            return "inline", [f"NavigationLink(destination: {name}()"] + indent(mods, 8) + \
                [") {", '    Text("Open")', "}"]
        if form == "foreach":
            return "inline", [f"ForEach(items, id: \\.self, content: {name}.init)"] + indent(mods, 4)
        flag = f"flag{len(flags)}"
        flags.append(flag)
        if form == "outside_sheet":
            return "inline", [f"Color.clear.sheet(isPresented: ${flag}) {{", f"    {name}()", "}"] + mods
        return "presentation", [f".{form}(isPresented: ${flag}) {{", f"    {name}()"] + indent(mods, 8) + ["}"]

    def view_file(self, v):
        ctx = Context("view")
        flags = []
        inline = []
        presentations = []
        for c in self.children[v]:
            where, chunk = self.child_chunk(v, c, ctx, flags)
            (inline if where == "inline" else presentations).append(chunk)
        hosted = [h for h, parent in self.host_in_view.items() if parent == v]
        methods = []
        for h in hosted:
            methods += ["", f"    func makeController{h}() -> UIViewController {{",
                        f"        UIHostingController(rootView: {self.type_name(h)}(){ROOT_MARK}hosting:{h}"]
            methods += indent(injection_lines(self.root_injection[("hosting", h)], ctx, self.rng), 12)
            methods += ["        )", "    }"]

        generic = "<Payload>" if v in self.generic else ""
        lines = ["import SwiftUI"]
        if hosted:
            lines.append("import UIKit")
        lines += ["", f"struct V{v}{generic}: View {{","    var item: Int = 0"]
        if any("ForEach" in line for chunk in inline for line in chunk):
            lines.append("    private let items = [1, 2, 3]")
        for t in sorted(self.requires[v]):
            if t in STORES:
                lines.append(f"    @EnvironmentObject var env{t}: {t}")
            elif self.rng.random() < 0.5:
                lines.append(f"    @Environment({t}.self) private var env{t}")
            else:
                lines.append(f"    @Environment({t}.self) private var env{t}: {t}")
        if v in self.optional:
            t = self.optional[v]
            lines.append(f"    @Environment({t}.self) private var opt{t}: {t}?")
        for flag in flags:
            lines.append(f"    @State private var {flag} = false")
        lines += ctx.declarations(4)
        lines += ["", "    var body: some View {", "        VStack {", f'            Text("V{v} \\(item)")']
        for chunk in inline:
            lines += indent(chunk, 12)
        lines.append("        }")
        for chunk in presentations:
            lines += indent(chunk, 8)
        lines.append("    }")
        lines += methods
        lines.append("}")

        if v in self.preview_views:
            pctx = Context("preview")
            body = self.root_line("preview", v, pctx, 4)
            if self.rng.random() < 0.6:
                lines += ["", "#Preview {"] + pctx.declarations(4) + body + ["}"]
            else:
                lines += ["", f"struct V{v}_Previews: PreviewProvider {{","    static var previews: some View {"]
                lines += pctx.declarations(8)
                lines += indent(self.root_line_return(body), 4)
                lines += ["    }", "}"]
        self.write(self.view_path(v), lines)

    def root_line_return(self, body):
        return ["return " + body[0].lstrip()] if len(body) == 1 else \
            [body[0].replace(body[0].lstrip(), "return " + body[0].lstrip())] + body[1:]

    def app_file(self):
        ctx = Context("app")
        on_group = self.rng.random() < 0.5
        if on_group:
            name = self.type_name(0)
            mods = injection_lines(self.root_injection[("app", 0)], ctx, self.rng)
            scene = ["        WindowGroup {", f"            {name}(){ROOT_MARK}app:0", "        }"] + indent(mods, 8)
        else:
            scene = ["        WindowGroup {"] + self.root_line("app", 0, ctx, 12) + ["        }"]
        lines = ["import SwiftUI", "", "@main", "struct GeneratedApp: App {"] + ctx.declarations(4)
        lines += ["", "    var body: some Scene {"] + scene + ["    }", "}"]
        self.write("App/GeneratedApp.swift", lines)

    def hosting_files(self):
        for h in self.hosting_tops:
            if h in self.host_in_view:
                continue
            form = self.rng.choice(["direct", "local", "subclass"])
            name = self.type_name(h)
            lines = ["import SwiftUI", "import UIKit", ""]
            if form == "subclass":
                ctx = Context("preview")
                mods = indent(injection_lines(self.root_injection[("hosting", h)], ctx, self.rng), 12)
                lines += [f"final class HostingFactory{h}: UIHostingController<AnyView> {{", "    init() {"]
                lines += ctx.declarations(8)
                lines += [f"        super.init(rootView: AnyView({name}(){ROOT_MARK}hosting:{h}"] + mods
                lines += ["        ))", "    }", "}"]
            else:
                ctx = Context("host")
                mods = indent(injection_lines(self.root_injection[("hosting", h)], ctx, self.rng), 12)
                if form == "local":
                    body = [f"        let root = {name}(){ROOT_MARK}hosting:{h}"] + mods
                    body += ["        return UIHostingController(rootView: root)"]
                else:
                    body = [f"        UIHostingController(rootView: {name}(){ROOT_MARK}hosting:{h}"] + mods
                    body += ["        )"]
                lines += [f"final class HostingFactory{h} {{"] + ctx.declarations(4)
                lines += ["", "    @MainActor", "    func make() -> UIViewController {"] + body + ["    }", "}"]
            self.write(f"UIKit/HostingFactory{h}.swift", lines)

    def support_files(self):
        lines = ["import Combine", "import Observation", ""]
        for m in MODELS:
            lines += ["@Observable", f"final class {m} {{", f"    static let shared = {m}()",
                      f"    static func preview() -> {m} {{ {m}() }}", "    var count = 0", "}", ""]
        for s in STORES:
            lines += [f"final class {s}: ObservableObject {{", f"    static let shared = {s}()",
                      "    @Published var count = 0", "}", ""]
        lines += [f"func make{HATCH_TYPE}() -> {HATCH_TYPE} {{ {HATCH_TYPE}.shared }}"]
        self.write("Models/Models.swift", lines)

        lines = ["import SwiftUI", "", "extension View {"]
        for t in sorted(EXTENSION_TYPES):
            lines += [f"    func with{t}() -> some View {{", f"        environment({t}.shared)", "    }", ""]
        lines += ["    func withCoreModels() -> some View {",
                  "        withModel0()", "            .modifier(InjectModel6())", "            .withModel1()",
                  "    }", "}", ""]
        for t in sorted(MODIFIER_TYPES):
            lines += [f"struct Inject{t}: ViewModifier {{", "    func body(content: Content) -> some View {",
                      f"        content.environment({t}.shared)", "    }", "}", ""]
        self.write("Support/Injection.swift", lines)

    def write(self, rel, lines):
        clean = []
        for number, line in enumerate(lines, start=1):
            if ROOT_MARK in line:
                text, marker = line.split(ROOT_MARK)
                kind, top = marker.split(":")
                self.root_edges[(kind, int(top))] = (rel, number)
                line = text
            clean.append(line)
        self.files[rel] = "\n".join(clean) + "\n"

    def expected(self):
        violations = []
        for kind, top in self.root_ids:
            missing = self.needs[top] - self.root_injection[(kind, top)]
            rel, line = self.root_edges[(kind, top)]
            for t in sorted(missing):
                violations.append({"file": rel, "line": line, "type": t, "kind": kind})
        added = {(self.root_edges[r][0], self.root_edges[r][1], t) for r, t in self.added}
        found = {(v["file"], v["line"], v["type"]) for v in violations}
        assert added == found, "simulation disagrees with the added violations"
        return {
            "n": self.n,
            "seed": self.seed,
            "added": len(self.added),
            "violations": sorted(violations, key=lambda v: (v["file"], v["line"], v["type"])),
            "stats": {
                "views": self.n,
                "roots": len(self.root_ids),
                "hosting_roots": len(self.hosting_tops),
                "hosting_in_view": len(self.host_in_view),
                "preview_roots": len(self.preview_views),
                "requirements": sum(len(r) for r in self.requires.values()),
                "optional_environment": len(self.optional),
                "edges": sum(len(c) for c in self.children.values()),
            },
        }

    def generate(self, out):
        self.build_graph()
        self.support_files()
        self.app_file()
        self.hosting_files()
        for v in range(self.n):
            self.view_file(v)
        for rel, text in self.files.items():
            path = os.path.join(out, rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as handle:
                handle.write(text)
        expected = self.expected()
        with open(os.path.join(out, "expected.json"), "w") as handle:
            json.dump(expected, handle, indent=1)
        return expected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, required=True)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--violations", type=int)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    expected = GeneratedApp(args.n, args.seed, args.violations).generate(args.out)
    print(json.dumps({"out": args.out, "added": expected["added"], **expected["stats"]}))


if __name__ == "__main__":
    main()
