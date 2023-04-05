import Combine

public protocol StorageProtocol<Snapshot> {
    associatedtype Changes: Publisher<VersionedChange<Snapshot.Version, Snapshot.Change>, Never>
    associatedtype Snapshot: StorageSnapshot

    var changes: Changes { get }
    func withSnapshot<T>(body: @escaping @Sendable (Snapshot) throws -> T) async throws -> T
}

extension StorageProtocol {
    public typealias Version = Snapshot.Version
    public typealias Change = Snapshot.Change
}

public protocol StorageSnapshot {
    associatedtype Version: VersionVector
    associatedtype Change: Equatable & Sendable

    var version: Version { get throws }
}
