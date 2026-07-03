import Foundation

enum AppBranding {
    static let name = "TabletBasic"
    static let version: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()
    static let fullTitle = "\(name) Version \(version)"
    static let authorName = "Andrey Sapunov"
    static let copyright = "Copyright 2026 \(authorName)"
    static let guideTitle = "\(name) Learning Guide"
    static let linkedInURL = URL(string: "https://www.linkedin.com/in/andrey-sapunov/")!
    static let repositoryURL = URL(string: "https://github.com/asaptf/TabletBasic")!
}