import XCTest

@testable import SwiftTUI

final class ListTests: XCTestCase {
  func test_identifiableList_updatesBindingOnRowFocusChange() throws {
    struct Item: Identifiable {
      let id: Int
      let title: String
    }

    let selection = SelectionBox<Int>()
    let items = [
      Item(id: 1, title: "One"),
      Item(id: 2, title: "Two"),
      Item(id: 3, title: "Three"),
    ]

    let node = buildRootNode(
      List(items, selection: binding(for: selection)) { item in
        Button(item.title, action: {})
      }
    )
    let (window, control) = try install(node: node, size: Size(width: 30, height: 5))

    XCTAssertEqual(selection.value, 1)
    moveDown(window: window, rootControl: control, size: Size(width: 30, height: 5))
    XCTAssertEqual(selection.value, 2)
    moveDown(window: window, rootControl: control, size: Size(width: 30, height: 5))
    XCTAssertEqual(selection.value, 3)
  }

  func test_list_withForEachAndTag_updatesSelectionBinding() throws {
    let selection = SelectionBox<String>()
    let values = ["A", "B", "C"]

    let node = buildRootNode(
      List(selection: binding(for: selection)) {
        ForEach(values, id: \.self) { value in
          Button(value, action: {})
            .tag(value)
        }
      }
    )
    let (window, control) = try install(node: node, size: Size(width: 20, height: 4))

    XCTAssertEqual(selection.value, "A")
    moveDown(window: window, rootControl: control, size: Size(width: 20, height: 4))
    XCTAssertEqual(selection.value, "B")
  }

  func test_list_lazyRealizesOnlyVisibleRows() throws {
    let values = Array(0..<100)

    let node = buildRootNode(
      List {
        ForEach(values, id: \.self) { value in
          Button("\(value)", action: {})
        }
      }
    )
    let (_, control) = try install(node: node, size: Size(width: 20, height: 5))

    let realizedRows = realizedListRowCount(in: control)
    XCTAssertGreaterThanOrEqual(realizedRows, 5)
    XCTAssertLessThanOrEqual(realizedRows, 7)
  }

  func test_list_scrollsAndRealizesNextRowsDuringDownNavigation() throws {
    struct Row: Identifiable {
      let id: Int
    }

    let selection = SelectionBox<Int>()
    let rows = (0..<50).map { Row(id: $0) }

    let node = buildRootNode(
      List(rows, selection: binding(for: selection)) { row in
        Button("\(row.id)", action: {})
      }
    )
    let (window, control) = try install(node: node, size: Size(width: 20, height: 4))

    for _ in 0..<8 {
      moveDown(window: window, rootControl: control, size: Size(width: 20, height: 4))
    }

    XCTAssertEqual(selection.value, 8)
    let realizedRows = realizedListRowCount(in: control)
    XCTAssertGreaterThanOrEqual(realizedRows, 4)
    XCTAssertLessThanOrEqual(realizedRows, 7)
  }

  func test_selectionList_preservesNestedControlFocus() throws {
    let rows = [0, 1]
    let selection = SelectionBox<Int>()

    let node = buildRootNode(
      List(selection: binding(for: selection)) {
        ForEach(rows, id: \.self) { row in
          HStack {
            Button("L\(row)", action: {})
            Button("R\(row)", action: {})
          }
          .tag(row)
        }
      }
    )
    let (window, control) = try install(node: node, size: Size(width: 20, height: 4))
    let firstResponder = window.firstResponder

    XCTAssertEqual(selection.value, 0)

    moveRight(window: window, rootControl: control, size: Size(width: 20, height: 4))
    XCTAssertEqual(selection.value, 0)
    XCTAssertFalse(window.firstResponder === firstResponder)

    moveDown(window: window, rootControl: control, size: Size(width: 20, height: 4))
    XCTAssertEqual(selection.value, 1)
  }

  func test_selectionList_rowWithoutTag_isNotSelectionSource() throws {
    let selection = SelectionBox<String>()

    let node = buildRootNode(
      List(selection: binding(for: selection)) {
        Button("Tagged A", action: {}).tag("a")
        Button("Untagged", action: {})
        Button("Tagged C", action: {}).tag("c")
      }
    )
    let (window, control) = try install(node: node, size: Size(width: 30, height: 4))

    XCTAssertEqual(selection.value, "a")

    moveDown(window: window, rootControl: control, size: Size(width: 30, height: 4))
    XCTAssertEqual(selection.value, "a")

    moveDown(window: window, rootControl: control, size: Size(width: 30, height: 4))
    XCTAssertEqual(selection.value, "c")
  }

  private func buildRootNode<V: View>(_ view: V) -> Node {
    let node = Node(view: VStack(content: view).view)
    node.build()
    return node
  }

  private func install(node: Node, size: Size) throws -> (Window, Control) {
    let control = try XCTUnwrap(node.control)
    let window = Window()
    window.addControl(control)
    control.layout(size: size)
    window.firstResponder = control.firstSelectableElement
    window.firstResponder?.becomeFirstResponder()
    control.layout(size: size)
    return (window, control)
  }

  private func moveDown(window: Window, rootControl: Control, size: Size) {
    guard let next = window.firstResponder?.selectableElement(below: 0) else { return }
    window.firstResponder?.resignFirstResponder()
    window.firstResponder = next
    window.firstResponder?.becomeFirstResponder()
    rootControl.layout(size: size)
  }

  private func moveRight(window: Window, rootControl: Control, size: Size) {
    guard let next = window.firstResponder?.selectableElement(rightOf: 0) else { return }
    window.firstResponder?.resignFirstResponder()
    window.firstResponder = next
    window.firstResponder?.becomeFirstResponder()
    rootControl.layout(size: size)
  }

  private func realizedListRowCount(in control: Control) -> Int {
    control.treeDescription
      .split(separator: "\n")
      .filter { $0.contains("ListRowControl") }
      .count
  }

  private func binding<T>(for box: SelectionBox<T>) -> Binding<T?> {
    Binding(get: { box.value }, set: { box.value = $0 })
  }
}

private final class SelectionBox<T> {
  var value: T?
}
