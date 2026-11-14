@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            // snagless: provides Cart
            Leaf().environment(makeCart())
        }
    }
}
