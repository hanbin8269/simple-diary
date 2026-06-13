import Foundation

/// Manages a launchd login agent that opens the app at a set time each day.
enum AutoOpenAgent {
    static let label = "com.hanbin.ilgi.autoopen"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// Register opening the app daily at hour:minute (updates an existing one).
    static func install(hour: Int, minute: Int) throws {
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": label,
            // Opening by bundle ID survives moving the app
            "ProgramArguments": ["/usr/bin/open", "-b", "com.hanbin.ilgi"],
            "StartCalendarInterval": ["Hour": hour, "Minute": minute],
            "RunAtLoad": false,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        run(["bootout", "gui/\(getuid())/\(label)"]) // remove any existing registration (ignored if absent)
        let status = run(["bootstrap", "gui/\(getuid())", plistURL.path])
        guard status == 0 else {
            throw NSError(
                domain: "AutoOpenAgent", code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "launchctl bootstrap 실패 (코드 \(status))"]
            )
        }
    }

    /// Disable auto-open
    static func uninstall() {
        run(["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
    }

    @discardableResult
    private static func run(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
