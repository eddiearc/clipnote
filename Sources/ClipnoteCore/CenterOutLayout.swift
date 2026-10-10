/// 从中间往两边铺：第 0 项居中，奇数向左、偶数向右。
public enum CenterOutLayout {
    public static func displayOrder<T>(_ items: [T]) -> [T] {
        guard !items.isEmpty else { return [] }
        var left: [T] = []
        var right: [T] = []
        for (index, item) in items.enumerated() where index > 0 {
            if index % 2 == 1 {
                left.insert(item, at: 0)
            } else {
                right.append(item)
            }
        }
        return left + [items[0]] + right
    }
}
