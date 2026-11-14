package enum Frameworks {
    package static let modules: Set<String> = [
        "Swift", "SwiftUI", "UIKit", "AppKit", "WidgetKit", "Observation", "Combine",
    ]

    package static let hostingTypes: Set<String> = [
        "UIHostingController", "NSHostingController", "NSHostingView", "UIHostingConfiguration",
    ]

    package static let nonViewTypes: Set<String> = [
        "String", "Substring", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Date", "URL", "Data",
        "UUID", "Task", "Optional", "Result",
    ]
}
