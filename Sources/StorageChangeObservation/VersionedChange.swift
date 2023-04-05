public struct VersionedChange<Version: VersionVector, Change: Equatable & Sendable>: Equatable, Sendable {
    public var oldVersion: Version
    public var newVersion: Version
    public var change: Change

    public init(oldVersion: Version, newVersion: Version, change: Change) {
        self.oldVersion = oldVersion
        self.newVersion = newVersion
        self.change = change
    }
}
