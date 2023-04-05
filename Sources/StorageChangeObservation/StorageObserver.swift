public protocol StorageObserver<Snapshot, Output>: Sendable {
    associatedtype Snapshot: StorageSnapshot
    associatedtype Output

    func fetch(in snapshot: Snapshot) throws -> Output
    func isRelevant(_ change: Change) -> Bool
    func reduce(into state: inout Output, change: Change) throws
    var initialValue: Output { get }
}

extension StorageObserver {
    public typealias Version = Snapshot.Version
    public typealias Change = Snapshot.Change
}
