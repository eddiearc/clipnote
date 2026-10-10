import ClipnoteCore
import SwiftUI

struct ReminderChip: View {
    let item: ReminderItem
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    @State private var sway: Double = 0
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: -Layout.clipBite) {
            BinderClip()
                .zIndex(1)
            stickyBody
        }
        .rotationEffect(.degrees(hovering ? restTilt * 0.2 : sway), anchor: .top)
        .offset(y: hovering ? -1 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: hovering)
        .onAppear {
            sway = restTilt
            let duration = 2.8 + abs(restTilt) * 0.4
            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                sway = restTilt + (restTilt >= 0 ? 0.9 : -0.9)
            }
        }
        .onHover { hovering = $0; showDetail = $0 }
        .popover(isPresented: $showDetail, arrowEdge: .bottom) {
            DetailPopover(item: item)
                .frame(width: 260)
                .padding(12)
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: ChipHitKey.self,
                    value: [item.id: geo.frame(in: .named("line"))]
                )
            }
        }
    }

    private var stickyBody: some View {
        HStack(alignment: .top, spacing: 6) {
            // 只有左侧圆圈会完成；点标题 / 正文不得写回 EventKit。
            Button(action: onComplete) {
                Circle()
                    .strokeBorder(ink.opacity(0.42), lineWidth: 1.15)
                    .frame(width: 12, height: 12)
                    .frame(width: 20, height: 20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Click the circle to mark complete")
            .accessibilityLabel("Mark \(item.title) complete")

            Button(action: { PrivacySettings.openRemindersApp() }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(metaLine)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(dueColor)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open in Reminders")
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText + " Open in Reminders.")
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(width: Layout.cardWidth, height: Layout.cardHeight, alignment: .topLeading)
        .background {
            PaperStock(seed: paperSeed, scheme: colorScheme)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
        .shadow(color: .black.opacity(hovering ? 0.16 : 0.10), radius: hovering ? 7 : 2.5, y: hovering ? 5 : 2)
        .shadow(color: .black.opacity(0.08), radius: 0.6, y: 0.5)
    }

    /// 由 id 决定的静止倾角，左右略不齐。
    private var restTilt: Double {
        var hasher = Hasher()
        hasher.combine(item.id)
        let bucket = abs(hasher.finalize() % 9)
        return Double(bucket) * 0.26 - 1.05
    }

    private var paperSeed: UInt64 {
        var hasher = Hasher()
        hasher.combine(item.id)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.95, green: 0.91, blue: 0.84)
            : Color(red: 0.22, green: 0.17, blue: 0.12)
    }

    private var metaLine: String {
        var parts = [item.listName]
        if let due = DueFormatter.string(for: item) {
            parts.append(due)
        }
        return parts.joined(separator: " · ")
    }

    private var dueColor: Color {
        if item.isOverdue() { return Color(red: 0.72, green: 0.22, blue: 0.16) }
        if item.isDueToday() { return Color(red: 0.72, green: 0.42, blue: 0.12) }
        return ink.opacity(0.55)
    }

    private var accessibilityText: String {
        if let due = DueFormatter.string(for: item) {
            return "\(item.title), \(item.listName), \(due)"
        }
        return "\(item.title), \(item.listName)"
    }
}


private struct DetailPopover: View {
    let item: ReminderItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(metaLine)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            if !item.notes.isEmpty {
                Divider()
                Text(item.notes)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaLine: String {
        var parts = [item.listName]
        if let due = DueFormatter.string(for: item) {
            parts.append(due)
        }
        if let p = priorityLabel {
            parts.append(p)
        }
        return parts.joined(separator: " · ")
    }

    private var priorityLabel: String? {
        switch item.priority {
        case 1: return "High priority"
        case 5: return "Medium priority"
        case 9: return "Low priority"
        default: return nil
        }
    }
}

/// 暖白纸：纤维、浅格线、上沿受光、夹口压痕、右下折角。
private struct PaperStock: View {
    let seed: UInt64
    let scheme: ColorScheme

    var body: some View {
        Canvas { context, size in
            let shape = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2.5)
            let dark = scheme == .dark
            let paper = dark
                ? Color(red: 0.34, green: 0.30, blue: 0.25)
                : Color(red: 0.975, green: 0.945, blue: 0.885)
            let shade = dark
                ? Color(red: 0.24, green: 0.21, blue: 0.17)
                : Color(red: 0.86, green: 0.78, blue: 0.66)
            let fiber = dark
                ? Color.white.opacity(0.045)
                : Color(red: 0.45, green: 0.32, blue: 0.16).opacity(0.065)
            let rule = dark
                ? Color(red: 0.55, green: 0.62, blue: 0.72).opacity(0.11)
                : Color(red: 0.35, green: 0.45, blue: 0.62).opacity(0.11)

            context.fill(shape, with: .color(paper))
            context.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(dark ? 0.07 : 0.34),
                        Color.clear,
                        shade.opacity(0.55)
                    ]),
                    startPoint: CGPoint(x: size.width * 0.15, y: 0),
                    endPoint: CGPoint(x: size.width * 0.8, y: size.height)
                )
            )

            context.drawLayer { layer in
                layer.clip(to: shape)
                var bite = Path()
                bite.addRect(CGRect(x: 0, y: 0, width: size.width, height: 8))
                layer.fill(
                    bite,
                    with: .linearGradient(
                        Gradient(colors: [Color.black.opacity(dark ? 0.28 : 0.09), Color.clear]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: 8)
                    )
                )

                var rules = Path()
                var y: CGFloat = 36
                while y < size.height - 14 {
                    rules.move(to: CGPoint(x: 12, y: y))
                    rules.addLine(to: CGPoint(x: size.width - 16, y: y))
                    y += 13
                }
                layer.stroke(rules, with: .color(rule), lineWidth: 0.55)

                var rng = SplitMix(state: seed == 0 ? 0xA5A5_F00D : seed)
                for _ in 0..<22 {
                    let px = rng.next() * size.width
                    let py = rng.next() * size.height
                    let r = 0.4 + rng.next() * 0.65
                    let speck = Path(ellipseIn: CGRect(x: px, y: py, width: r, height: r * (0.55 + rng.next() * 0.5)))
                    layer.fill(speck, with: .color(fiber))
                }

                let fold: CGFloat = 10
                var underside = Path()
                underside.move(to: CGPoint(x: size.width - fold, y: size.height))
                underside.addLine(to: CGPoint(x: size.width, y: size.height - fold))
                underside.addLine(to: CGPoint(x: size.width, y: size.height))
                underside.closeSubpath()
                layer.fill(underside, with: .color(shade))

                var flap = Path()
                flap.move(to: CGPoint(x: size.width - fold, y: size.height))
                flap.addQuadCurve(
                    to: CGPoint(x: size.width, y: size.height - fold),
                    control: CGPoint(x: size.width - fold * 0.15, y: size.height - fold * 0.15)
                )
                flap.addLine(to: CGPoint(x: size.width - fold * 0.72, y: size.height - fold * 0.15))
                flap.closeSubpath()
                layer.fill(
                    flap,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(dark ? 0.08 : 0.5),
                            paper
                        ]),
                        startPoint: CGPoint(x: size.width - fold, y: size.height - 1),
                        endPoint: CGPoint(x: size.width - 1, y: size.height - fold)
                    )
                )
                layer.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: size.width - fold, y: size.height - 0.4))
                        path.addLine(to: CGPoint(x: size.width - 0.4, y: size.height - fold))
                    },
                    with: .color(Color.black.opacity(dark ? 0.35 : 0.12)),
                    lineWidth: 0.6
                )
            }

            context.stroke(shape, with: .color(Color.black.opacity(dark ? 0.4 : 0.12)), lineWidth: 0.7)
            var highlight = Path()
            highlight.move(to: CGPoint(x: 3, y: 1.1))
            highlight.addLine(to: CGPoint(x: size.width - 3, y: 1.1))
            context.stroke(highlight, with: .color(Color.white.opacity(dark ? 0.08 : 0.55)), lineWidth: 0.7)
        }
    }
}

/// 扣在细杆上的金属书签夹：宽帽、窄舌、弹簧孔。
private struct BinderClip: View {
    var body: some View {
        ZStack {
            ClipSilhouette()
                .fill(Color(red: 0.16, green: 0.17, blue: 0.19))
                .offset(y: 1.1)
                .frame(width: 24, height: Layout.clipHeight)
            ClipSilhouette()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.94, blue: 0.96),
                            Color(red: 0.70, green: 0.73, blue: 0.77),
                            Color(red: 0.40, green: 0.43, blue: 0.47),
                            Color(red: 0.58, green: 0.61, blue: 0.66)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 24, height: Layout.clipHeight)
            ClipSilhouette()
                .stroke(Color.white.opacity(0.45), lineWidth: 0.6)
                .frame(width: 24, height: Layout.clipHeight)
                .offset(y: -0.3)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.27, blue: 0.30),
                            Color(red: 0.78, green: 0.80, blue: 0.84)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.15
                )
                .background {
                    Circle()
                        .fill(Color.black.opacity(0.28))
                        .padding(1.3)
                }
                .frame(width: 5.5, height: 5.5)
                .offset(y: -2.5)
        }
        .frame(width: 26, height: Layout.clipHeight)
        .shadow(color: .black.opacity(0.28), radius: 1.1, y: 0.8)
        .allowsHitTesting(false)
    }
}

private struct ClipSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.06, y: h * 0.46))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.50, y: h * 0.02),
            control: CGPoint(x: w * 0.02, y: h * 0.02)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.46),
            control: CGPoint(x: w * 0.98, y: h * 0.02)
        )
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.46))
        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.96))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.34, y: h * 0.96),
            control: CGPoint(x: w * 0.50, y: h * 1.08)
        )
        path.addLine(to: CGPoint(x: w * 0.30, y: h * 0.46))
        path.closeSubpath()
        return path
    }
}

private struct SplitMix {
    var state: UInt64

    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z % 10_000) / 10_000.0
    }
}

enum DueFormatter {
    static func string(for item: ReminderItem, now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let due = item.dueDate else { return nil }
        if item.isOverdue(now: now, calendar: calendar) {
            if calendar.isDate(due, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
                return item.hasDueTime ? "Overdue yesterday \(time(due))" : "Overdue yesterday"
            }
            return item.hasDueTime ? "Overdue \(short(due, hasTime: true))" : "Overdue \(short(due, hasTime: false))"
        }
        if calendar.isDateInToday(due) {
            return item.hasDueTime ? "Due today \(time(due))" : "Due today"
        }
        if calendar.isDateInTomorrow(due) {
            return item.hasDueTime ? "Tomorrow \(time(due))" : "Tomorrow"
        }
        return short(due, hasTime: item.hasDueTime)
    }

    private static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func short(_ date: Date, hasTime: Bool) -> String {
        if hasTime {
            return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
