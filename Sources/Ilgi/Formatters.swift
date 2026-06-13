import Foundation

enum Formatters {
    /// For filenames/identifiers: "2026-06-11"
    static let dateKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Long Korean date, e.g. "2026년 6월 11일 목요일"
    static let longKorean: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter
    }()

    /// Short Korean date, e.g. "6월 11일 목요일"
    static let shortKorean: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()
}

/// Converts a dateKey ("2026-06-11") to a Korean date string; omits the year for this year's entries.
func koreanDate(forKey key: String, alwaysYear: Bool = false) -> String {
    guard let date = Formatters.dateKey.date(from: key) else { return key }
    let calendar = Calendar.current
    let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
    if sameYear && !alwaysYear {
        return Formatters.shortKorean.string(from: date)
    }
    return Formatters.longKorean.string(from: date)
}
