import XCTest

@testable import SwiftTUI

final class LifecycleModifierTests: XCTestCase {
  func test_onAppear_runsOnceForRepeatedLayout() throws {
    var count = 0

    struct TestView: View {
      let action: () -> Void

      var body: some View {
        Text("Value").onAppear(action)
      }
    }

    let node = buildRootNode(TestView(action: { count += 1 }))

    try layout(node)
    try layout(node)

    XCTAssertEqual(count, 1)
  }

  func test_onAppear_usesLatestClosureBeforeFirstLayout() throws {
    var value = "unset"

    struct TestView: View {
      let action: () -> Void

      var body: some View {
        Text("Value").onAppear(action)
      }
    }

    let node = buildRootNode(TestView(action: { value = "old" }))
    updateRootNode(node, with: TestView(action: { value = "new" }))

    try layout(node)

    XCTAssertEqual(value, "new")
  }

  func test_onAppear_runsAgainAfterRemoveAndReinsert() throws {
    var count = 0

    struct TestView: View {
      let show: Bool
      let action: () -> Void

      var body: some View {
        if show {
          Text("Value").onAppear(action)
        }
      }
    }

    let node = buildRootNode(TestView(show: true, action: { count += 1 }))
    try layout(node)

    updateRootNode(node, with: TestView(show: false, action: { count += 1 }))
    try layout(node)

    updateRootNode(node, with: TestView(show: true, action: { count += 1 }))
    try layout(node)

    XCTAssertEqual(count, 2)
  }

  func test_task_startsAfterLayout() async throws {
    let probe = TaskProbe()

    struct TestView: View {
      let probe: TaskProbe

      var body: some View {
        Text("Value").task {
          await probe.recordStart(id: 0)
        }
      }
    }

    let node = buildRootNode(TestView(probe: probe))
    try layout(node)

    let started = await waitUntil { await probe.startCount() == 1 }
    XCTAssertTrue(started)
  }

  func test_task_withoutID_doesNotRestartOnUpdate() async throws {
    let probe = TaskProbe()

    struct TestView: View {
      let show: Bool
      let title: String
      let probe: TaskProbe

      var body: some View {
        if show {
          Text(title).task {
            await probe.recordStart(id: 0)
            while !Task.isCancelled {
              try? await Task.sleep(nanoseconds: 10_000_000)
            }
            await probe.recordCancellation(id: 0)
          }
        }
      }
    }

    let node = buildRootNode(TestView(show: true, title: "A", probe: probe))
    try layout(node)

    let started = await waitUntil { await probe.startCount() == 1 }
    XCTAssertTrue(started)

    updateRootNode(node, with: TestView(show: true, title: "B", probe: probe))
    try layout(node)

    try? await Task.sleep(nanoseconds: 50_000_000)
    let startCount = await probe.startCount()
    XCTAssertEqual(startCount, 1)

    updateRootNode(node, with: TestView(show: false, title: "B", probe: probe))
    try layout(node)

    let cancelled = await waitUntil { await probe.cancellationCount() == 1 }
    XCTAssertTrue(cancelled)
  }

  func test_task_withID_restartsWhenIDChanges() async throws {
    let probe = TaskProbe()

    struct TestView: View {
      let show: Bool
      let id: Int
      let probe: TaskProbe

      var body: some View {
        if show {
          Text("Value \(id)").task(id: id) {
            await probe.recordStart(id: id)
            while !Task.isCancelled {
              try? await Task.sleep(nanoseconds: 10_000_000)
            }
            await probe.recordCancellation(id: id)
          }
        }
      }
    }

    let node = buildRootNode(TestView(show: true, id: 1, probe: probe))
    try layout(node)

    let didStartFirst = await waitUntil { await probe.startedIDs() == [1] }
    XCTAssertTrue(didStartFirst)

    updateRootNode(node, with: TestView(show: true, id: 2, probe: probe))
    try layout(node)

    let didRestart = await waitUntil { await probe.startCount() == 2 }
    XCTAssertTrue(didRestart)
    let startedIDs = await probe.startedIDs()
    XCTAssertEqual(startedIDs, [1, 2])
    let didCancelOldTask = await waitUntil { await probe.cancelledIDs().contains(1) }
    XCTAssertTrue(didCancelOldTask)

    updateRootNode(node, with: TestView(show: false, id: 2, probe: probe))
    try layout(node)

    let didCancelSecondTask = await waitUntil { await probe.cancelledIDs().contains(2) }
    XCTAssertTrue(didCancelSecondTask)
  }

  func test_task_cancelsWhenViewDisappears() async throws {
    let probe = TaskProbe()

    struct TestView: View {
      let show: Bool
      let probe: TaskProbe

      var body: some View {
        if show {
          Text("Value").task {
            await probe.recordStart(id: 0)
            while !Task.isCancelled {
              try? await Task.sleep(nanoseconds: 10_000_000)
            }
            await probe.recordCancellation(id: 0)
          }
        }
      }
    }

    let node = buildRootNode(TestView(show: true, probe: probe))
    try layout(node)

    let started = await waitUntil { await probe.startCount() == 1 }
    XCTAssertTrue(started)

    updateRootNode(node, with: TestView(show: false, probe: probe))
    try layout(node)

    let cancelled = await waitUntil { await probe.cancellationCount() == 1 }
    XCTAssertTrue(cancelled)
  }

  // MARK: - Throwing task tests

  func test_throwingTask_ignoresCancellationErrorWhenViewDisappears() async throws {
    let probe = TaskProbe()

    struct TestView: View {
      let show: Bool
      let probe: TaskProbe

      var body: some View {
        if show {
          Text("Value").task {
            await probe.recordStart(id: 0)
            // Simulate a long-running async operation that throws CancellationError
            // when the task is cancelled (e.g. navigating back).
            try await Task.sleep(nanoseconds: 10_000_000_000)
            // If we get here, the task wasn't cancelled
          }
        }
      }
    }

    let node = buildRootNode(TestView(show: true, probe: probe))
    try layout(node)

    let started = await waitUntil { await probe.startCount() == 1 }
    XCTAssertTrue(started)

    // Remove the view while the task is still running — this cancels the task,
    // which causes Task.sleep to throw CancellationError. The framework should
    // catch this silently instead of crashing.
    updateRootNode(node, with: TestView(show: false, probe: probe))
    try layout(node)

    // Give time for the cancellation to propagate
    try? await Task.sleep(nanoseconds: 50_000_000)

    // If we reach here without crashing, the CancellationError was handled correctly.
  }

  func test_throwingTask_withID_ignoresCancellationErrorWhenIDChanges() async throws {
    let probe = TaskProbe()

    struct TestView: View {
      let show: Bool
      let id: Int
      let probe: TaskProbe

      var body: some View {
        if show {
          Text("Value \(id)").task(id: id) {
            await probe.recordStart(id: id)
            // Simulate a long-running operation that throws when cancelled
            try await Task.sleep(nanoseconds: 10_000_000_000)
          }
        }
      }
    }

    let node = buildRootNode(TestView(show: true, id: 1, probe: probe))
    try layout(node)

    let didStartFirst = await waitUntil { await probe.startedIDs() == [1] }
    XCTAssertTrue(didStartFirst)

    // Change the ID — this cancels the previous task and starts a new one.
    // The old task's CancellationError should be silently handled.
    updateRootNode(node, with: TestView(show: true, id: 2, probe: probe))
    try layout(node)

    let didRestart = await waitUntil { await probe.startCount() == 2 }
    XCTAssertTrue(didRestart)
    let startedIDs = await probe.startedIDs()
    XCTAssertEqual(startedIDs, [1, 2])

    // Remove the view entirely to cancel the second task as well
    updateRootNode(node, with: TestView(show: false, id: 2, probe: probe))
    try layout(node)

    try? await Task.sleep(nanoseconds: 50_000_000)
    // If we reach here, both CancellationErrors were handled correctly.
  }

  func test_throwingTask_handlesNonCancellationErrorWithoutCrash() async throws {
    let probe = TaskProbe()

    struct SomeError: Error {}

    struct TestView: View {
      let probe: TaskProbe

      var body: some View {
        Text("Value").task {
          await probe.recordStart(id: 0)
          // Throw a non-cancellation error; the framework should catch this
          // silently without crashing.
          throw SomeError()
        }
      }
    }

    let node = buildRootNode(TestView(probe: probe))
    try layout(node)

    let started = await waitUntil { await probe.startCount() == 1 }
    XCTAssertTrue(started)

    // Give time for the error to be thrown and caught
    try? await Task.sleep(nanoseconds: 50_000_000)
    // If we reach here, the non-cancellation error was handled gracefully.
  }

  func test_throwingTask_withID_handlesNonCancellationErrorWithoutCrash() async throws {
    let probe = TaskProbe()

    struct SomeError: Error {}

    struct TestView: View {
      let id: Int
      let probe: TaskProbe

      var body: some View {
        Text("Value \(id)").task(id: id) {
          await probe.recordStart(id: id)
          throw SomeError()
        }
      }
    }

    let node = buildRootNode(TestView(id: 1, probe: probe))
    try layout(node)

    let started = await waitUntil { await probe.startCount() == 1 }
    XCTAssertTrue(started)

    try? await Task.sleep(nanoseconds: 50_000_000)
    // If we reach here, the error was handled gracefully.
  }

  private func buildRootNode<V: View>(_ view: V) -> Node {
    let node = Node(view: VStack(content: view).view)
    node.build()
    return node
  }

  private func updateRootNode<V: View>(_ node: Node, with view: V) {
    node.update(using: VStack(content: view).view)
  }

  private func layout(_ node: Node) throws {
    let control = try XCTUnwrap(node.control)
    control.layout(size: Size(width: 80, height: 24))
  }

  private func waitUntil(
    retries: Int = 200,
    intervalNanoseconds: UInt64 = 10_000_000,
    condition: @escaping @Sendable () async -> Bool
  ) async -> Bool {
    for _ in 0..<retries {
      if await condition() { return true }
      try? await Task.sleep(nanoseconds: intervalNanoseconds)
    }
    return await condition()
  }
}

private actor TaskProbe {
  private var started: [Int] = []
  private var cancelled: [Int] = []

  func recordStart(id: Int) {
    started.append(id)
  }

  func recordCancellation(id: Int) {
    cancelled.append(id)
  }

  func startCount() -> Int {
    started.count
  }

  func cancellationCount() -> Int {
    cancelled.count
  }

  func startedIDs() -> [Int] {
    started
  }

  func cancelledIDs() -> [Int] {
    cancelled
  }
}
