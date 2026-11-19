import Testing

@Suite
struct AppDelegateTests {
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
                "Leaf.swift:6:12: error: `Leaf` needs `AppDelegate`: preview `Leaf` → Leaf (Leaf.swift:3)",
                "Leaf.swift:6:12: error: `Leaf` needs `SceneDelegate`: preview `Leaf` → Leaf (Leaf.swift:2)",
            ]
        )
    }

    @Test
    func delegateOfOneAppCountsForEveryApp() {
        let first = """
            @main struct First: App {
                @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
                var body: some Scene { WindowGroup { Text("first") } }
            }
            """
        let leaf = """
            struct Leaf: View {
                @Environment(AppDelegate.self) private var appDelegate
                var body: some View { Text("leaf") }
            }
            """
        let sources = [
            "First.swift": first,
            "Second.swift": "struct Second: App { var body: some Scene { WindowGroup { Leaf() } } }",
            "Delegates.swift": "@Observable final class AppDelegate: NSObject, UIApplicationDelegate {}",
            "Leaf.swift": leaf,
        ]
        #expect(TestProject(sources).errors() == [])
    }
}
