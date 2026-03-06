import XCTest

@testable import SwiftTUI

final class StateTests: XCTestCase {
  func test_state_getWithNilNode_returnsInitialValue() {
    let state = State<String>(wrappedValue: "initial")
    // valueReference.node is nil (never wired to a Node), simulating
    // access after the view's node has been deallocated.
    XCTAssertEqual(state.wrappedValue, "initial")
  }

  func test_state_setWithNilNode_doesNotCrash() {
    let state = State<String>(wrappedValue: "initial")
    // Setting @State when node is nil (e.g. after view removal)
    // should be a safe no-op, not a fatal error.
    state.wrappedValue = "updated"
    // Value should still be the initial value since the node is nil
    // and the set was a no-op.
    XCTAssertEqual(state.wrappedValue, "initial")
  }
}
