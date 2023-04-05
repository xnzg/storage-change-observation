import XCTest
import ComposableArchitecture
@testable import StorageChangeObservation

@available(iOS 16, *)
final class StorageObservingTests: XCTestCase {
    struct BasicFeature: Reducer {
        struct State {
            @StorageObserving<SingleIntegerObserver>
            var value: Int

            init(observer: SingleIntegerObserver, storage: SingleIntegerStorage) {
                _value = .init(observer: observer, storage: storage)
            }
        }

        typealias Action = StorageObservingAction<SingleIntegerObserver>

        var body: some Reducer<State, Action> {
            Scope(state: \State.$value, action: CasePath(Action.self)) {
                StorageObservingReducer()
            }
        }
    }

    @MainActor
    func testBasic() async {
        typealias A = BasicFeature.Action

        let storage = SingleIntegerStorage()
        let observer = SingleIntegerObserver()

        let initialState = BasicFeature.State(observer: observer, storage: storage)
        let store = TestStore(initialState: initialState, reducer: BasicFeature(), observe: \.value)

        await store.send(.start)
        await store.receive(A.init(action: .update(0)))

        await storage.update(to: 1)
        await store.receive(A.init(action: .update(1))) {
            $0 = 1
        }

        await store.send(.pause)
        await storage.update(to: 2)
        await store.send(.resume)

        await store.receive(A.init(action: .update(2))) {
            $0 = 2
        }

        await store.send(.stop)
        await store.finish()
    }
}
