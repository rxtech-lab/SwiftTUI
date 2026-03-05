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

  // MARK: - NavigationPath tests

  func test_navigationPath_appendAndCount() {
    var path = NavigationPath()
    XCTAssertTrue(path.isEmpty)
    XCTAssertEqual(path.count, 0)

    path.append(42)
    XCTAssertEqual(path.count, 1)
    XCTAssertFalse(path.isEmpty)

    path.append("hello")
    XCTAssertEqual(path.count, 2)

    path.removeLast()
    XCTAssertEqual(path.count, 1)

    path.removeLast()
    XCTAssertTrue(path.isEmpty)
  }

  func test_navigationPath_removeLastMultiple() {
    var path = NavigationPath()
    path.append(1)
    path.append(2)
    path.append(3)
    path.removeLast(2)
    XCTAssertEqual(path.count, 1)
  }

  // MARK: - Value-based NavigationLink + navigationDestination tests

  func test_navigationLink_value_pushesViaNavigationDestination() throws {
    let node = buildRootNode(
      NavigationStack {
        VStack {
          NavigationLink("Go", value: 42)
        }
        .navigationDestination(for: Int.self) { value in
          Text("Value: \(value)")
        }
      }
    )

    let (window, control) = try install(node: node, size: Size(width: 40, height: 8))

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: Size(width: 40, height: 8))

    let rendered = render(control: control, size: Size(width: 40, height: 8))
    XCTAssertTrue(rendered.contains("Value: 42"))
  }

  func test_navigationStack_pathBinding_push() throws {
    struct PathTestView: View {
      @State var path = NavigationPath()

      var body: some View {
        NavigationStack(path: $path) {
          VStack {
            NavigationLink("Go", value: 99)
          }
          .navigationDestination(for: Int.self) { value in
            Text("Detail \(value)")
          }
        }
      }
    }

    let node = buildRootNode(PathTestView())
    let (window, control) = try install(node: node, size: Size(width: 40, height: 8))

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: Size(width: 40, height: 8))

    let rendered = render(control: control, size: Size(width: 40, height: 8))
    XCTAssertTrue(rendered.contains("Detail 99"))
  }

  func test_navigationStack_pathBinding_backPops() throws {
    struct PathTestView: View {
      @State var path = NavigationPath()

      var body: some View {
        NavigationStack(path: $path) {
          VStack {
            NavigationLink("Go", value: 1)
          }
          .navigationDestination(for: Int.self) { value in
            Text("Detail \(value)")
          }
        }
      }
    }

    let size = Size(width: 40, height: 8)
    let node = buildRootNode(PathTestView())
    let (window, control) = try install(node: node, size: size)

    // Push
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)
    XCTAssertTrue(render(control: control, size: size).contains("Detail 1"))

    // Pop via back
    moveDown(window: window, rootControl: control, size: size)
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Go"))
    XCTAssertFalse(rendered.contains("Detail"))
  }

  // MARK: - Existing tests

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
