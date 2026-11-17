import Testing

@Suite
struct RepresentableTests {
    @Test
    func representableIsAViewWithItsOwnRequirements() {
        let label = """
            struct Label: UIViewRepresentable {
                @Environment(Cart.self) private var cart
                func makeUIView(context: Context) -> UILabel { UILabel() }
                func updateUIView(_ label: UILabel, context: Context) {}
            }
            """
        #expect(
            TestProject(["App.swift": Fixture.app(showing: "Label()"), "Label.swift": label]).errors() == [
                "App.swift:1:64: error: `Label` needs `Cart`: App `MyApp` → Label (Label.swift:2)"
            ]
        )
    }

    @Test(arguments: [
        "UIHostingController(rootView: Leaf())",
        "let controller = UIHostingController(rootView: Leaf())\n        return controller",
    ])
    func hostingControllerARepresentableReturnsIsPartOfTheRepresentable(maker: String) {
        let hosted = """
            struct Hosted: UIViewControllerRepresentable {
                func makeUIViewController(context: Context) -> UIViewController {
                    \(maker)
                }
                func updateUIViewController(_ controller: UIViewController, context: Context) {}
            }
            """
        let sources = ["Hosted.swift": hosted, "Leaf.swift": Fixture.leafView]
        let provided = TestProject(
            sources.merging(["App.swift": Fixture.app(showing: "Hosted().environment(Cart())")]) { $1 }
        )
        let missing = TestProject(sources.merging(["App.swift": Fixture.app(showing: "Hosted()")]) { $1 })
        #expect(provided.errors() == [])
        #expect(
            missing.errors() == [
                "App.swift:1:64: error: `Leaf` needs `Cart`: App `MyApp` → Hosted → Leaf (Leaf.swift:2)"
            ]
        )
    }

    @Test
    func hostingControllerPresentedFromARepresentableStartsEmpty() {
        let hosted = """
            final class Presenter: UIViewController {
                override func viewDidAppear(_ animated: Bool) {
                    present(UIHostingController(rootView: Leaf()), animated: false)
                }
            }
            struct Hosted: UIViewControllerRepresentable {
                func makeUIViewController(context: Context) -> Presenter { Presenter() }
                func updateUIViewController(_ controller: Presenter, context: Context) {}
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Hosted().environment(Cart())"), "Hosted.swift": hosted,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(
            TestProject(sources).errors() == [
                "Hosted.swift:3:47: error: `Leaf` needs `Cart`: "
                    + "hosting controller in `Presenter` → Leaf (Leaf.swift:2)"
            ]
        )
    }
}
