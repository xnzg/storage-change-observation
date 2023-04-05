import XCTest
import Dependencies
import TestableOSLog
@testable import StorageChangeObservation

@available(iOS 16, *)
final class StorageObservationTests: XCTestCase {
    func testBasic() async {
        let storage = SingleIntegerStorage()
        let observer = SingleIntegerObserver()

        let task = await withScopedLifetime(StorageObservation(observer: observer, storage: storage)) {
            let task = taskToCollect($0.outputs)

            await megaYield()
            for i in 1...3 {
                await storage.update(to: i)
                await megaYield()
            }

            return task
        }

        let taskResult = await task.value
        XCTAssertEqual(taskResult, [0, 1, 2, 3])
    }

    func testBatching() async {
        let storage = SingleIntegerStorage()
        let observer = SingleIntegerObserver()

        let task = await withScopedLifetime(StorageObservation(observer: observer, storage: storage)) {
            let task = taskToCollect($0.outputs)

            await megaYield()
            await storage.update(to: 1)
            await storage.update(to: 2)
            await storage.update(to: 3)
            await megaYield()

            return task
        }

        let taskResult = await task.value
        XCTAssertEqual(taskResult, [0, 3])
    }

    func testFilterIrrelevant() async {
        let storage = SingleIntegerStorage()
        let observer = SingleIntegerObserver()

        let task = await withScopedLifetime(StorageObservation(observer: observer, storage: storage)) {
            let task = taskToCollect($0.outputs)

            await megaYield()
            for i in [1, 1, 1, 2] {
                await storage.update(to: i)
                await megaYield()
            }

            return task
        }

        let taskResult = await task.value
        XCTAssertEqual(taskResult, [0, 1, 2])
    }

    func testPauseResumeNoDirty() async {
        let storage = SingleIntegerStorage()
        let observer = SingleIntegerObserver()

        let task = await withScopedLifetime(StorageObservation(observer: observer, storage: storage)) {
            let task = taskToCollect($0.outputs)

            await megaYield()
            await storage.update(to: 1)
            await megaYield()
            await $0.pause()
            await megaYield()
            await storage.update(to: 1)
            await megaYield()
            await $0.resume()
            await megaYield()
            await storage.update(to: 2)
            await megaYield()

            return task
        }

        let taskResult = await task.value
        XCTAssertEqual(taskResult, [0, 1, 2])
    }

    func testPauseResumeDirty() async {
        let storage = SingleIntegerStorage()
        let observer = SingleIntegerObserver()

        let task = await withScopedLifetime(StorageObservation(observer: observer, storage: storage)) {
            let task = taskToCollect($0.outputs)

            await megaYield()
            await storage.update(to: 1)
            await megaYield()
            await $0.pause()
            await megaYield()
            await storage.update(to: 2)
            await megaYield()
            await $0.resume()
            await megaYield()

            return task
        }

        let taskResult = await task.value
        XCTAssertEqual(taskResult, [0, 1, 2])
    }
}
