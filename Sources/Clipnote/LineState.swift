import Combine
import CoreGraphics
import Foundation

/// 备忘夹面板的展示状态（滑出 / 命中区域），与提醒数据分离。
@MainActor
final class LineState: ObservableObject {
    @Published var revealed = false
    @Published var hitRects: [String: CGRect] = [:]
}
