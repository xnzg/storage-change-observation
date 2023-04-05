public protocol VersionVector: Equatable, Sendable, CustomStringConvertible {
    func isCompatible(with other: Self) -> Bool
    static func < (lhs: Self, rhs: Self) -> Bool
    static func > (lhs: Self, rhs: Self) -> Bool
}

extension VersionVector {
    public func isCompatible(with other: Self) -> Bool {
        self == other || self < other || self > other
    }
}
