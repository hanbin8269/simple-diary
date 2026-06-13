import Foundation

// Day One 공식 내보내기(JSON 또는 JSON이 든 ZIP)를 읽어 날짜별 .md 파일로 변환한다.
// AppKit에 의존하지 않는 순수 로직 — UI(파일 선택/알림)는 DiaryStore 쪽에 있다.

enum DayOneImportError: LocalizedError {
    case unzipFailed
    case noJSONFound
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unzipFailed:
            return "ZIP 압축을 풀지 못했어요."
        case .noJSONFound:
            return "선택한 파일에서 Day One JSON을 찾지 못했어요. Day One에서 '내보내기 → JSON'으로 만든 파일을 선택해 주세요."
        case .unreadable(let name):
            return "\(name) 파일을 읽지 못했어요."
        }
    }
}

struct DayOneImportSummary {
    var sourceEntries = 0 // 파싱된 Day One 항목 수
    var createdDays = 0   // 새로 만든 날짜 파일 수
    var skippedDays = 0   // 이미 일기가 있어 건너뛴 날 수
    var backupURL: URL?
}

enum DayOneImporter {

    private struct Journal: Decodable {
        let entries: [Entry]?
    }

    private struct Entry: Decodable {
        let creationDate: String?
        let timeZone: String?
        let text: String?
    }

    private static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseDate(_ string: String) -> Date? {
        isoPlain.date(from: string) ?? isoFractional.date(from: string)
    }

    /// source(.json 또는 .zip)를 entriesDir에 날짜별 파일로 가져온다.
    static func run(source: URL, entriesDir: URL) throws -> DayOneImportSummary {
        let fm = FileManager.default

        var jsonURLs: [URL]
        var cleanupDir: URL?
        if source.pathExtension.lowercased() == "zip" {
            let extracted = try unzip(source)
            cleanupDir = extracted
            jsonURLs = findJSONs(in: extracted)
        } else {
            jsonURLs = [source]
        }
        defer { if let dir = cleanupDir { try? fm.removeItem(at: dir) } }

        guard !jsonURLs.isEmpty else { throw DayOneImportError.noJSONFound }

        // Day One 항목 → 날짜키별 세그먼트 (항목의 타임존 기준 현지 날짜로 묶는다)
        struct Segment {
            let date: Date
            let timeLabel: String
            let text: String
        }
        var byDay: [String: [Segment]] = [:]
        var sourceCount = 0

        for jsonURL in jsonURLs {
            guard let data = try? Data(contentsOf: jsonURL) else {
                throw DayOneImportError.unreadable(jsonURL.lastPathComponent)
            }
            // 저널이 아닌 json(메타데이터 등)은 조용히 무시
            guard let journal = try? JSONDecoder().decode(Journal.self, from: data),
                  let entries = journal.entries else { continue }

            for entry in entries {
                guard let creationString = entry.creationDate,
                      let created = parseDate(creationString) else { continue }
                let text = cleanText(entry.text ?? "")
                guard !text.isEmpty else { continue }
                sourceCount += 1

                let timeZone = entry.timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = timeZone
                formatter.dateFormat = "yyyy-MM-dd"
                let dateKey = formatter.string(from: created)
                formatter.dateFormat = "HH:mm"
                let timeLabel = formatter.string(from: created)

                byDay[dateKey, default: []].append(
                    Segment(date: created, timeLabel: timeLabel, text: text)
                )
            }
        }

        var summary = DayOneImportSummary(sourceEntries: sourceCount)
        guard sourceCount > 0 else { return summary }

        for (dateKey, segments) in byDay {
            let destination = entriesDir.appendingPathComponent("\(dateKey).md")
            if fm.fileExists(atPath: destination.path) {
                summary.skippedDays += 1
                continue
            }
            let ordered = segments.sorted { $0.date < $1.date }
            let body: String
            if ordered.count == 1 {
                body = ordered[0].text
            } else {
                // 하루에 여러 항목이면 시간 라벨을 붙여 병합
                body = ordered.map { "[\($0.timeLabel)]\n\($0.text)" }.joined(separator: "\n\n")
            }
            try body.write(to: destination, atomically: true, encoding: .utf8)
            if let last = ordered.last {
                try? fm.setAttributes([.modificationDate: last.date], ofItemAtPath: destination.path)
            }
            summary.createdDays += 1
        }
        return summary
    }

    /// Day One 본문 정리: 첨부 모먼트는 라벨로, 이스케이프된 문장부호는 복원
    static func cleanText(_ raw: String) -> String {
        var text = raw
        text = text.replacingOccurrences(
            of: #"!\[\]\(dayone-moment:/video/[A-Za-z0-9]+\)"#,
            with: "(동영상)", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"!\[\]\(dayone-moment:/audio/[A-Za-z0-9]+\)"#,
            with: "(오디오)", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"!\[\]\(dayone-moment:/pdfAttachment/[A-Za-z0-9]+\)"#,
            with: "(PDF)", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"!\[\]\(dayone-moment://[A-Za-z0-9]+\)"#,
            with: "(사진)", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"!\[\]\(dayone-moment:[^)]*\)"#,
            with: "(첨부)", options: .regularExpression)
        // Day One이 마크다운 문장부호 앞에 붙이는 백슬래시 제거: "\." → "."
        text = text.replacingOccurrences(
            of: #"\\([\\`*_{}\[\]()#+\-.!>~"'])"#,
            with: "$1", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unzip(_ url: URL) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ilgi-dayone-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-qq", url.path, "-d", dir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw DayOneImportError.unzipFailed }
        return dir
    }

    private static func findJSONs(in dir: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension.lowercased() == "json" }
    }
}
