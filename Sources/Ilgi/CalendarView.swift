import SwiftUI

/// Month calendar shown on the home screen. Days with entries are shaded like grass by length.
struct MonthCalendarView: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var monthAnchor = Date() // any date within the displayed month

    private static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter
    }()

    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = Locale(identifier: "ko_KR")
        return c
    }

    private let cellSize: CGFloat = 28
    private let cellSpacing: CGFloat = 5
    private var gridWidth: CGFloat { cellSize * 7 + cellSpacing * 6 }

    var body: some View {
        VStack(spacing: 8) {
            header
            weekdayRow
            grid
        }
        .frame(width: gridWidth)
    }

    // MARK: - Month navigation

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)) ?? monthAnchor
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        if let shifted = calendar.date(byAdding: .month, value: delta, to: monthStart) {
            monthAnchor = shifted
        }
    }

    private var header: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("이전 달")

            Spacer()

            Text(Self.monthTitle.string(from: monthStart))
                .font(.system(size: 13, weight: .semibold))
                .onTapGesture { monthAnchor = Date() }
                .help("이번 달로 돌아가기")

            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(isCurrentMonth)
            .help("다음 달")
        }
        .frame(width: gridWidth)
    }

    // MARK: - Weekday / day grid

    private var weekdaySymbols: [(symbol: String, weekday: Int)] {
        let symbols = calendar.veryShortWeekdaySymbols // [Sun, Mon, ..., Sat]
        return (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return (symbols[weekday - 1], weekday)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: cellSpacing) {
            ForEach(weekdaySymbols, id: \.weekday) { item in
                Text(item.symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        item.weekday == 1 ? Color.red.opacity(0.75)
                            : item.weekday == 7 ? Color.blue.opacity(0.7)
                            : Color.secondary
                    )
                    .frame(width: cellSize)
            }
        }
    }

    /// Day array padded with nil at both ends, length a multiple of 7
    private var dayCells: [Int?] {
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading)
        cells += (1...dayCount).map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var grid: some View {
        let cells = dayCells
        let counts = Dictionary(uniqueKeysWithValues: store.entries.map { ($0.dateKey, $0.text.count) })
        let todayKey = store.todayKey
        return VStack(spacing: cellSpacing) {
            ForEach(0..<(cells.count / 7), id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { column in
                        if let day = cells[row * 7 + column] {
                            let key = dateKey(day: day)
                            DayCell(
                                day: day,
                                chars: counts[key],
                                isToday: key == todayKey,
                                isSelected: key == store.selectedDateKey,
                                isFuture: key > todayKey,
                                size: cellSize
                            ) {
                                open(dateKey: key, hasEntry: counts[key] != nil)
                            }
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private func dateKey(day: Int) -> String {
        guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return "" }
        return Formatters.dateKey.string(from: date)
    }

    /// Today opens immediately; past entries go through the Touch ID unlock first.
    private func open(dateKey: String, hasEntry: Bool) {
        if dateKey == store.todayKey {
            store.selectToday()
            return
        }
        guard hasEntry else { return }
        store.revealPast { store.selectedDateKey = dateKey }
    }
}

private struct DayCell: View {
    let day: Int
    let chars: Int? // nil means no entry
    let isToday: Bool
    let isSelected: Bool
    let isFuture: Bool
    let size: CGFloat
    let action: () -> Void
    @State private var hovering = false

    private var clickable: Bool { isToday || (chars != nil && !isFuture) }

    /// Darkens in 4 steps by character count, GitHub-grass style
    private func intensity(_ chars: Int) -> Double {
        switch chars {
        case ..<100: return 0.30
        case ..<300: return 0.55
        case ..<700: return 0.80
        default: return 1.0
        }
    }

    private var fill: Color {
        guard let chars, chars > 0 else {
            return Color.primary.opacity(isFuture ? 0.03 : 0.055)
        }
        return Theme.accent.opacity(intensity(chars))
    }

    private var numberColor: Color {
        if let chars, chars >= 300 { return .white }
        if isFuture { return Color.primary.opacity(0.25) }
        return chars != nil ? .primary : .secondary
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(fill)
                if isToday {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent, lineWidth: 1.5)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.45), lineWidth: 1.5)
                }
                if hovering && clickable {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                }
                Text("\(day)")
                    .font(.system(size: 10.5, weight: (chars != nil || isToday) ? .semibold : .regular))
                    .foregroundStyle(numberColor)
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!clickable)
        .onHover { hovering = $0 }
        .help(helpText)
    }

    private var helpText: String {
        if isToday { return "오늘 일기" }
        if let chars { return "\(chars)자 · 클릭해서 열기" }
        return ""
    }
}
