import ComposableArchitecture
import Dependencies
import Yumi

@propertyWrapper
public struct StorageObserving<Observer: StorageObserver> {
    public typealias Snapshot = Observer.Snapshot
    public typealias Output = Observer.Output
    public typealias Storage = any StorageProtocol<Snapshot>

    public let observer: Observer
    public let storage: Storage

    var observation: StorageObservation<Observer>?
    var output: Output?
    public internal(set) var error: Error?

    public var hasStarted: Bool {
        observation != nil
    }

    public init(observer: Observer, storage: Storage) {
        self.observer = observer
        self.storage = storage
    }

    public var wrappedValue: Output {
        output ?? observer.initialValue
    }

    public var projectedValue: Self {
        get { self }
        set { self = newValue }
    }
}

extension StorageObserving: Equatable where Output: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.output == rhs.output && memoryEqual(lhs.error, rhs.error)
    }
}

public struct StorageObservingAction<Observer: StorageObserver> {
    public typealias Output = Observer.Output

    enum Action {
        case start
        case stop
        case pause
        case resume
        case update(Output)
        case setError(MemoryEqual<Error>)
        case clearError
    }

    var action: Action

    public static var start: Self { .init(action: .start) }
    public static var stop: Self { .init(action: .stop) }
    public static var pause: Self { .init(action: .pause) }
    public static var resume: Self { .init(action: .resume) }
    public static var clearError: Self { .init(action: .clearError) }
}

extension StorageObservingAction.Action: Equatable where Observer.Output: Equatable {}
extension StorageObservingAction: Equatable where Observer.Output: Equatable {}

public struct StorageObservingReducer<Observer: StorageObserver>: Reducer {
    public typealias State = StorageObserving<Observer>
    public typealias Action = StorageObservingAction<Observer>

    struct ObservationID: Hashable {
        var typeID: ObjectIdentifier
        var actorID: ObjectIdentifier

        init(observation: StorageObservation<Observer>) {
            typeID = ObjectIdentifier(Observer.self)
            actorID = ObjectIdentifier(observation)
        }
    }

    public init() {}

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action.action {
        case .start:
            precondition(!state.hasStarted)
            state.observation = .init(observer: state.observer, storage: state.storage)

            let readOutputs = Effect<Action>.run { [outputs = state.observation!.outputs] send in
                for await output in outputs {
                    await send(.init(action: .update(output)))
                }
            }
            let readErrors = Effect<Action>.run { [errors = state.observation!.errors] send in
                for await error in errors {
                    await send(.init(action: .setError(.init(wrappedValue: error))))
                }
            }
            return Effect.merge(readOutputs, readErrors)

        case .stop:
            precondition(state.hasStarted)
            state.observation = nil

        case .pause:
            return Effect.fireAndForget { [observation = state.observation!] in
                await observation.pause()
            }

        case .resume:
            return Effect.fireAndForget { [observation = state.observation!] in
                await observation.resume()
            }

        case .update(let output):
            state.output = output

        case .setError(let wrappedError):
            state.error = wrappedError.wrappedValue

        case .clearError:
            state.error = nil
        }

        return .none
    }
}
