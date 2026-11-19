import Testing

@Suite
struct ProviderExtensionTests {
    @Test
    func providerExtensionsWithOneNameInTwoModulesShareWhatTheyProvide() {
        let project = TestProject(modules: [
            "Theming": [
                "Theming/Themed.swift": "public extension View { func themed() -> some View { environment(Cart()) } }"
            ],
            "Plain": ["Plain/Themed.swift": "public extension View { func themed() -> some View { self } }"],
            "App": [
                "App/App.swift": "import Plain\n" + Fixture.app(showing: "Leaf().themed()"),
                "App/Leaf.swift": Fixture.leafView,
            ],
        ])
        #expect(project.errors() == [])
    }

    @Test
    func providerOverloadsShareWhatTheyProvide() {
        let support = """
            extension View {
                func themed() -> some View { environment(Cart()) }
                func themed(_ isOn: Bool) -> some View { self }
            }
            """
        let sources = [
            "App.swift": Fixture.app(showing: "Leaf().themed(true)"), "Support.swift": support,
            "Leaf.swift": Fixture.leafView,
        ]
        #expect(TestProject(sources).errors() == [])
    }
}
