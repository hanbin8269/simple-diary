import Foundation

/// 매일 정해진 시간에 앱을 여는 launchd 로그인 에이전트를 관리한다.
enum AutoOpenAgent {
    static let label = "com.hanbin.ilgi.autoopen"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// 매일 hour:minute에 앱을 열도록 등록(이미 있으면 갱신)
    static func install(hour: Int, minute: Int) throws {
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": label,
            // 번들 ID로 열면 앱을 옮겨도 경로가 깨지지 않는다
            "ProgramArguments": ["/usr/bin/open", "-b", "com.hanbin.ilgi"],
            "StartCalendarInterval": ["Hour": hour, "Minute": minute],
            "RunAtLoad": false,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        run(["bootout", "gui/\(getuid())/\(label)"]) // 기존 등록 제거(없으면 무시)
        let status = run(["bootstrap", "gui/\(getuid())", plistURL.path])
        guard status == 0 else {
            throw NSError(
                domain: "AutoOpenAgent", code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "launchctl bootstrap 실패 (코드 \(status))"]
            )
        }
    }

    /// 자동 열기 해제
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
