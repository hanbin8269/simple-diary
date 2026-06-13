import SwiftUI

/// Grass-style month calendar (iOS version scaled up for touch).
struct MobileCalendarView: View {
    @EnvironmentObject private var store: MobileStore
    @State private var monthAnchor = Date()
    /// Called when a date is picked to move to the editor (to dismiss the sheet).
    let onPicked: () -> Void

    init(onPicked: @escaping () -> Void = {}) {
        self.onPicked = onPicked
    }

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

    private let cellSpacing: CGFloat = 6

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayRow
            grid
        }
    }

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
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            Text(Self.monthTitle.string(from: monthStart))
                .font(.system(size: 16, weight: .semibold))
                .onTapGesture { monthAnchor = Date() }
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 4)
    }

    private var weekdaySymbols: [(symbol: String, weekday: Int)] {
        let symbols = calendar.veryShortWeekdaySymbols
        return (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return (symbols[weekday - 1], weekday)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: cellSpacing) {
            ForEach(weekdaySymbols, id: \.weekday) { item in
                Text(item.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        item.weekday == 1 ? Color.red.opacity(0.75)
                            : item.weekday == 7 ? Color.blue.opacity(0.7)
                            : Color.secondary
                    )
                    .frame(maxWidth: .infinity)
            }
        }
    }

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
                            MobileDayCell(
                                day: day,
                                chars: counts[key],
                                isToday: key == todayKey,
                                isSelected: key == store.selectedDateKey,
                                isFuture: key > todayKey
                            ) {
                                open(dateKey: key, hasEntry: counts[key] != nil)
                            }
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
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

    private func open(dateKey: String, hasEntry: Bool) {
        if dateKey == store.todayKey {
            store.selectToday()
            onPicked()
            return
        }
        guard hasEntry else { return }
        store.revealPast { [self] in
            store.selectedDateKey = dateKey
            onPicked()
        }
    }
}

private struct MobileDayCell: View {
    let day: Int
    let chars: Int?
    let isToday: Bool
    let isSelected: Bool
    let isFuture: Bool
    let action: () -> Void

    private var clickable: Bool { isToday || (chars != nil && !isFuture) }

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
                RoundedRectangle(cornerRadius: 8).fill(fill)
                if isToday {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.accent, lineWidth: 2)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.45), lineWidth: 2)
                }
                Text("\(day)")
                    .font(.system(size: 13, weight: (chars != nil || isToday) ? .semibold : .regular))
                    .foregroundStyle(numberColor)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!clickable)
    }
}
