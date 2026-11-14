import Foundation

enum LaunchArguments {
    static var listsCases: Bool {
        UserDefaults.standard.bool(forKey: "list")
    }

    static var runtimeCase: RuntimeCase? {
        UserDefaults.standard.string(forKey: "case").flatMap(RuntimeCase.init(rawValue:))
    }
}
