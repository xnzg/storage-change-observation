import Combine
import StorageChangeObservation

final actor SingleIntegerStorage: StorageProtocol {
    var snapshot = Snapshot(version: .init(value: 0), value: 0)
    nonisolated let changes = PassthroughSubject<VersionedChange<Snapshot.Version, Snapshot.Change>, Never>()

    func update(to value: Int) {
        let oldVersion = snapshot.version
        var newVersion = oldVersion
        newVersion.value += 1

        let change = value - snapshot.value
        snapshot = .init(version: newVersion, value: value)

        changes.send(.init(oldVersion: oldVersion, newVersion: newVersion, change: change))
    }

    func withSnapshot<T>(body: @escaping (Snapshot) throws -> T) async throws -> T {
        try body(snapshot)
    }

    struct Snapshot: StorageSnapshot {
        var version: Version
        var value: Int
    }
}

extension SingleIntegerStorage.Snapshot {
    struct Version: VersionVector {
        var value: UInt64
        var description: String {
            value.description
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.value < rhs.value
        }

        static func > (lhs: Self, rhs: Self) -> Bool {
            lhs.value > rhs.value
        }
    }

    typealias Change = Int
}

struct SingleIntegerObserver: StorageObserver {
    typealias Snapshot = SingleIntegerStorage.Snapshot
    typealias Output = Int

    func fetch(in snapshot: Snapshot) throws -> Int {
        snapshot.value
    }

    func isRelevant(_ change: Change) -> Bool {
        change != 0
    }

    func reduce(into state: inout Int, change: Change) throws {
        state += change
    }

    var initialValue: Int { 0 }
}
