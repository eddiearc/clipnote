import ClipnoteCore
import SwiftUI

struct LineView: View {
    @ObservedObject var store: ReminderStore
    @ObservedObject var line: LineState

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .top) {
                MemoBar(width: width)

                content
                    .frame(width: width, height: Layout.panelHeight, alignment: .top)
                    .padding(.top, 2)
            }
            .animation(.spring(response: 0.48, dampingFraction: 0.84), value: store.items.map(\.id))
            .offset(y: line.revealed ? 0 : -(Layout.panelHeight + 10))
            .animation(
                line.revealed
                    ? .spring(response: 0.4, dampingFraction: 0.84)
                    : .easeIn(duration: 0.2),
                value: line.revealed
            )
            .coordinateSpace(name: "line")
        }
        .onPreferenceChange(ChipHitKey.self) { rects in
            line.hitRects = rects
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.access {
        case .unknown, .requesting:
            StatusPill(text: "Asking for Reminders access…")
                .frame(maxWidth: .infinity)
        case .denied, .restricted:
            DeniedBanner()
                .frame(maxWidth: .infinity)
        case .authorized:
            if store.isLoading && store.items.isEmpty {
                StatusPill(text: "Loading reminders…")
                    .frame(maxWidth: .infinity)
            } else if store.items.isEmpty {
                StatusPill(text: store.lastError ?? "Inbox zero. New reminders will clip here.")
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 4) {
                    if let message = store.lastError {
                        StatusPill(text: message)
                    }
                    chipRow
                }
            }
        }
    }

    private var chipRow: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Layout.chipSpacing) {
                    ForEach(CenterOutLayout.displayOrder(store.items)) { item in
                        ReminderChip(item: item) {
                            Task { await store.complete(item) }
                        }
                    }
                }
                .padding(.horizontal, Layout.sideInset)
                .padding(.top, 1)
                .padding(.bottom, 8)
                .frame(minWidth: geo.size.width)
            }
        }
        .frame(height: Layout.clipHeight + Layout.cardHeightExpanded - Layout.clipBite + 60)
    }
}

/// 菜单栏下的细金属杆，夹子扣在上面。
private struct MemoBar: View {
    let width: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.35))
                .frame(height: Layout.barHeight)
                .offset(y: 0.7)
                .blur(radius: 0.4)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.80, blue: 0.84),
                            Color(red: 0.46, green: 0.48, blue: 0.52),
                            Color(red: 0.28, green: 0.30, blue: 0.34)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: Layout.barHeight)
            Capsule()
                .fill(Color.white.opacity(0.55))
                .frame(height: 1)
                .offset(y: -0.9)
        }
        .frame(width: max(80, width - 56), height: Layout.barHeight + 2)
        .padding(.top, Layout.barTop)
        .frame(width: width, alignment: .center)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.05),
                    .init(color: .black, location: 0.95),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .allowsHitTesting(false)
    }
}

private struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 22)
    }
}

private struct DeniedBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.trianglebadge.exclamationmark")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders access is off")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text("Grant full access in System Settings to clip your open reminders here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Button("Open System Settings") {
                PrivacySettings.openReminders()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: ChipHitKey.self,
                    value: ["denied-banner": geo.frame(in: .named("line"))]
                )
            }
        }
    }
}

struct ChipHitKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
