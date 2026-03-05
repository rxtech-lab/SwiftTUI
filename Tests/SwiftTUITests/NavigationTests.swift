import XCTest

@testable import SwiftTUI

final class NavigationTests: XCTestCase {
  func test_navigationLink_pushesInNavigationStack() throws {
    let node = buildRootNode(
      NavigationStack {
        NavigationLink("Go", destination: Text("Detail"))
      }
    )

    let (window, control) = try install(node: node, size: Size(width: 40, height: 8))

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: Size(width: 40, height: 8))

    let rendered = render(control: control, size: Size(width: 40, height: 8))
    XCTAssertTrue(rendered.contains("Detail"))
  }

  func test_backButton_appearsOnlyWhenPushed() throws {
    let node = buildRootNode(
      NavigationStack {
        NavigationLink("Go", destination: Text("Detail"))
      }
    )

    let (window, control) = try install(node: node, size: Size(width: 40, height: 8))

    XCTAssertFalse(render(control: control, size: Size(width: 40, height: 8)).contains("Back"))

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: Size(width: 40, height: 8))

    let rendered = render(control: control, size: Size(width: 40, height: 8))
    XCTAssertTrue(rendered.contains("Back"))
  }

  func test_backButton_popsDestinationOnEnter() throws {
    let size = Size(width: 40, height: 8)
    let node = buildRootNode(
      NavigationStack {
        NavigationLink("Go", destination: Text("Detail"))
      }
    )

    let (window, control) = try install(node: node, size: size)

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    moveDown(window: window, rootControl: control, size: size)
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Go"))
    XCTAssertFalse(rendered.contains("Back"))
  }

  func test_performBackAction_popsDestination() throws {
    let size = Size(width: 40, height: 8)
    let node = buildRootNode(
      NavigationStack {
        NavigationLink("Go", destination: Text("Detail"))
      }
    )

    let (window, control) = try install(node: node, size: size)

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    XCTAssertTrue(window.firstResponder?.performBackAction() == true)
    update(node: node, control: control, size: size)

    XCTAssertTrue(render(control: control, size: size).contains("Go"))
    XCTAssertFalse(render(control: control, size: size).contains("Back"))
  }

  func test_navigationSplitView_routesSidebarLinkToDetail() throws {
    let size = Size(width: 60, height: 10)
    let node = buildRootNode(
      NavigationSplitView {
        NavigationLink("Item", destination: Text("Detail A"))
      } detail: {
        Text("Default")
      }
    )

    let (window, control) = try install(node: node, size: size)

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Item"))
    XCTAssertTrue(rendered.contains("Detail A"))
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

  private func update(node: Node, control: Control, size: Size) {
    node.update(using: node.view)
    control.layout(size: size)
  }

  private func moveDown(window: Window, rootControl: Control, size: Size) {
    guard let next = window.firstResponder?.selectableElement(below: 0) else { return }
    window.firstResponder?.resignFirstResponder()
    window.firstResponder = next
    window.firstResponder?.becomeFirstResponder()
    rootControl.layout(size: size)
  }

  private func render(control: Control, size: Size) -> String {
    (0..<size.height.intValue)
      .map { line(control: control, width: size.width.intValue, line: $0) }
      .joined(separator: "\n")
  }

  private func line(control: Control, width: Int, line: Int) -> String {
    guard width > 0 else { return "" }
    return (0..<width).map { column in
      control.layer.cell(at: Position(column: Extended(column), line: Extended(line)))?.char ?? " "
    }.map(String.init).joined()
  }
}
