import Combine
import Dependencies
import Foundation
import TestableOSLog

public struct RetryError: Error {
    public var duration: Duration

    public init(duration: Duration) {
        self.duration = duration
    }
}

public final actor StorageObservation<Observer: StorageObserver> {
    public typealias Output = Observer.Output
    public typealias Snapshot = Observer.Snapshot
    public typealias Version = Snapshot.Version
    public typealias Change = Snapshot.Change

    private let observer: Observer
    private let storage: any StorageProtocol<Snapshot>

    @Dependency(\.continuousClock)
    private var clock
    @Dependency(\.logger)
    private var logger

    private let pendingChanges: LockIsolated<[VersionedChange<Version, Change>]>
    private var subscriptions: Set<AnyCancellable> = []

    public nonisolated let outputs: CurrentValueChannel<Output> = .init()
    public nonisolated let errors: CurrentValueChannel<Error> = .init()

    enum State {
        case initialFetching
        case observing(Output, Version)
        case idling(Output, Version)
        case empty
    }

    private var state: State = .empty

    public init<Storage: StorageProtocol<Snapshot>>(
        observer: Observer,
        storage: Storage
    ) {
        self.observer = observer
        self.storage = storage

        pendingChanges = .init([])

        var subscriptions: Set<AnyCancellable> = []
        storage.changes.sink { [unowned self, pendingChanges] change in
            pendingChanges.withValue {
                $0.append(change)
            }
            Task {
                await self.clearPendingChanges()
            }
        }.store(in: &subscriptions)

        Task { [subscriptions] in
            await bindSubscriptions(subscriptions)
        }
        Task {
            await resume()
        }
    }

    deinit {
        Task { [outputs, errors] in
            await outputs.finish()
            await errors.finish()
        }
    }

    private func bindSubscriptions(_ subscriptions: Set<AnyCancellable>) {
        self.subscriptions = subscriptions
    }

    private func unpackState() -> (Output, Version, Bool)? {
        switch state {
        case .initialFetching, .empty:
            return nil
        case .observing(let output, let version):
            return (output, version, false)
        case .idling(let output, let version):
            return (output, version, true)
        }
    }

    typealias Messages = LogMessages<Observer>

    private func retry(in duration: Duration) {
        logger.info(Messages.willRetry(duration))
        state = .empty

        Task { [weak self, clock] in
            try? await clock.sleep(for: duration)
            await self?.resume()
        }
    }

    private func clearPendingChanges() async {
        guard case ((var output, var version, let isIdling))? = unpackState() else { return }

        let list = pendingChanges.withValue {
            let list = $0
            $0 = []
            return list
        }
        var hasChanges = false

        for versioned in list {
            guard !(versioned.newVersion < version || versioned.newVersion == version) else { continue }
            guard versioned.oldVersion == version else {
                logger.error(Messages.versionMisalignment(version, versioned.oldVersion, versioned.newVersion))
                retry(in: .seconds(1))
                return
            }
            guard observer.isRelevant(versioned.change) else {
                version = versioned.newVersion
                continue
            }

            hasChanges = true
            guard !isIdling else {
                state = .empty
                return
            }

            do {
                try observer.reduce(into: &output, change: versioned.change)
            } catch {
                if let error = error as? RetryError {
                    logger.info(Messages.reducerRequestedRetry)
                    retry(in: error.duration)
                } else {
                    logger.error(Messages.reducerError)
                    retry(in: .seconds(1))
                }
                return
            }
            version = versioned.newVersion
        }

        if isIdling {
            state = .idling(output, version)
        } else {
            state = .observing(output, version)
            if hasChanges {
                await outputs.send(output)
            }
        }
    }

    public func pause() {
        switch state {
        case .observing(let output, let version):
            state = .idling(output, version)
        default:
            return
        }
    }

    public func resume() async {
        switch state {
        case .idling(let output, let version):
            state = .observing(output, version)
            return
        case .initialFetching, .observing:
            return
        default:
            break
        }

        state = .initialFetching
        logger.info(Messages.initialFetchingStarted)

        var lastError: Error?
        for i in 1...4 {
            guard i < 4 else {
                logger.error(Messages.initialFetchingFailed)
                await errors.send(lastError!)
                state = .empty
                return
            }

            do {
                let (output, version) = try await storage.withSnapshot { [observer] snapshot in
                    let output = try observer.fetch(in: snapshot)
                    let version = try snapshot.version
                    return (output, version)
                }

                logger.info(Messages.initialFetchingCompleted)
                state = .observing(output, version)
                await outputs.send(output)
                await clearPendingChanges()
                return
            } catch {
                lastError = error

                let duration: Duration = .seconds(Int(pow(2, Double(i))))
                logger.error(Messages.initialFetchingError(duration))
                try? await clock.sleep(for: duration)
            }
        }
    }
}
