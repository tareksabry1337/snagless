import SnaglessAnalysis
import Testing

@Suite
struct RootTests {
    @Test
    func appSceneWithoutTheInjectionIsAnError() {
        let app = """
            @main struct MyApp: App {
                var body: some Scene {
                    WindowGroup {
                        Leaf()
                    }
                }
            }
            """
        #expect(
            TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]).errors() == [
                "App.swift:4:13: error: `Leaf` is shown from App `MyApp` without `Cart`; required by Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func injectionOnTheSceneReachesItsContent() {
        let app = """
            @main struct MyApp: App {
                @State private var cart = Cart()
                var body: some Scene {
                    WindowGroup { Leaf() }
                        .environment(cart)
                }
            }
            """
        #expect(TestProject(["App.swift": app, "Leaf.swift": Fixture.leafView]).errors() == [])
    }

    @Test
    func sceneDeclaredInAnAppExtensionIsARoot() {
        let app = """
            @main struct MyApp: App {
                var body: some Scene { scene }
            }
            """
        let scene = """
            extension MyApp {
                var scene: some Scene {
                    WindowGroup { Leaf() }
                }
            }
            """
        #expect(
            TestProject(["App.swift": app, "App+Scene.swift": scene, "Leaf.swift": Fixture.leafView]).errors() == [
                "App+Scene.swift:3:23: error: `Leaf` is shown from App `MyApp` without `Cart`; required by Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func hostingControllerStartsEmptyAndIsNotAChildOfItsView() {
        let parent = """
            struct Parent: View {
                var body: some View { Text("x") }
                func controller() -> UIViewController {
                    UIHostingController(rootView: Leaf())
                }
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Parent().environment(Cart())"), "Parent.swift": parent,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "Parent.swift:4:39: error: `Leaf` is shown from a hosting controller in `Parent` without `Cart`; "
                    + "required by Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func hostingRootFollowsALocalRootView() {
        let host = """
            final class Host: UIViewController {
                override func viewDidLoad() {
                    let view = Leaf()
                        .environment(Store())
                    let child = UIHostingController(rootView: view)
                    addChild(child)
                }
            }
            """
        #expect(
            TestProject(["Host.swift": host, "Leaf.swift": Fixture.leafView]).errors() == [
                "Host.swift:3:20: error: `Leaf` is shown from a hosting controller in `Host` without `Cart`; "
                    + "required by Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func localRootViewIsNotAlsoAChildOfTheView() {
        let parent = """
            struct Parent: View {
                var body: some View { Text("x") }
                func controller() -> UIViewController {
                    let content = Leaf()
                    return UIHostingController(rootView: content)
                }
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Parent()"), "Parent.swift": parent, "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "Parent.swift:4:23: error: `Leaf` is shown from a hosting controller in `Parent` without `Cart`; "
                    + "required by Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func hostingSubclassesAndTheirRootViewInitializersAreRoots() {
        let host = """
            final class Host: UIHostingController<Leaf> {
                init() { super.init(rootView: Leaf()) }
            }
            func make() -> UIViewController { Host(rootView: Leaf().environment(Cart())) }
            """
        #expect(
            TestProject(["Host.swift": host, "Leaf.swift": Fixture.leafView]).errors() == [
                "Host.swift:2:35: error: `Leaf` is shown from a hosting controller in `Host` without `Cart`; "
                    + "required by Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func rootViewArgumentOfAPlainViewIsNotAHostingRoot() {
        let views = """
            struct Wrapper<Content: View>: View {
                let rootView: Content
                var body: some View { rootView }
            }
            struct Screen: View { var body: some View { Wrapper(rootView: Leaf()) } }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Screen().environment(Cart())"), "Views.swift": views,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [])
    }

    @Test
    func widgetStartsEmpty() {
        let widget = """
            struct MyWidget: Widget {
                var body: some WidgetConfiguration {
                    StaticConfiguration(kind: "k", provider: Provider()) { entry in Leaf() }
                }
            }
            """
        #expect(
            TestProject(["Widget.swift": widget, "Leaf.swift": Fixture.leafView]).errors() == [
                "Widget.swift:3:73: error: `Leaf` is shown from widget `MyWidget` without `Cart`; required by Leaf (Leaf.swift:2)."
            ]
        )
    }

    @Test
    func observableDelegatesAreInTheAppEnvironmentOnly() {
        let delegates = """
            @Observable final class SceneDelegate: NSObject, UIWindowSceneDelegate {}
            final class AppDelegate: NSObject, UIApplicationDelegate {
                func application(_ app: UIApplication, configurationForConnecting session: UISceneSession,
                                 options: UIScene.ConnectionOptions) -> UISceneConfiguration {
                    let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
                    configuration.delegateClass = SceneDelegate.self
                    return configuration
                }
            }
            """
        let leaf = """
            struct Leaf: View {
                @Environment(SceneDelegate.self) private var sceneDelegate
                @Environment(AppDelegate.self) private var appDelegate
                var body: some View { Text("leaf") }
            }
            #Preview { Leaf() }
            """
        let app = """
            @main struct MyApp: App {
                @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
                var body: some Scene { WindowGroup { Leaf() } }
            }
            """
        #expect(
            TestProject(["App.swift": app, "Delegates.swift": delegates, "Leaf.swift": leaf]).errors() == [
                "Leaf.swift:6:12: error: `Leaf` is shown from preview `Leaf` without `AppDelegate`; required by Leaf (Leaf.swift:3).",
                "Leaf.swift:6:12: error: `Leaf` is shown from preview `Leaf` without `SceneDelegate`; required by Leaf (Leaf.swift:2).",
            ]
        )
    }

    @Test
    func legacySheetsStartEmpty() {
        let parent = """
            struct Parent: View {
                var body: some View {
                    VStack {
                        Text("x").sheet(isPresented: .constant(true)) { Leaf() }
                        Text("y").popover(isPresented: .constant(true)) { Leaf().environment(Cart()) }
                    }
                    .environment(Cart())
                }
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Parent()"), "Parent.swift": parent, "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [])
        #expect(
            TestProject(sources).errors(options: AnalysisOptions(legacySheets: true)) == [
                "Parent.swift:4:61: error: `Leaf` is shown from a sheet in `Parent` without `Cart`; required by Leaf (Leaf.swift:2)."
                    + " With --legacy-sheets, a sheet starts with an empty environment."
            ]
        )
    }
}
