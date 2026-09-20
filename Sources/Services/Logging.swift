import OSLog

enum Logging {
    static let networking = Logger(subsystem: "com.khouryg.fryday", category: "Networking")
    static let uv = Logger(subsystem: "com.khouryg.fryday", category: "UV")
    static let health = Logger(subsystem: "com.khouryg.fryday", category: "Health")
    static let calculator = Logger(subsystem: "com.khouryg.fryday", category: "Calculator")
    static let widget = Logger(subsystem: "com.khouryg.fryday", category: "Widget")
    static let signpost = OSSignposter(subsystem: "com.khouryg.fryday", category: "Signpost")
}

