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

    // Back button does not auto-focus; navigate down to reach it
    focusBackButton(window: window, rootControl: control, size: size)
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

    // Back button doesn't auto-focus; find it and use performBackAction from there
    let backButton = control.firstSelectableElement
    XCTAssertTrue(backButton?.performBackAction() == true)
    update(node: node, control: control, size: size)

    XCTAssertTrue(render(control: control, size: size).contains("Go"))
    XCTAssertFalse(render(control: control, size: size).contains("Back"))
  }

  func test_backButton_reachableWhenNoOtherSelectableElement() throws {
    let size = Size(width: 40, height: 8)
    let node = buildRootNode(
      NavigationStack {
        NavigationLink("Go", destination: Text("Detail"))
      }
    )

    let (window, control) = try install(node: node, size: size)

    // Push to detail (only Text, no buttons)
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    // firstResponder should be nil since detail has no focusable content
    XCTAssertNil(window.firstResponder)
    XCTAssertTrue(render(control: control, size: size).contains("Back"))

    // Simulate arrow key when firstResponder is nil — should find back button
    let backButton = control.firstSelectableElement
    XCTAssertNotNil(backButton)
    window.firstResponder = backButton
    backButton?.becomeFirstResponder()

    // Back button is now focused and can be activated
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Go"))
    XCTAssertFalse(rendered.contains("Back"))
  }

  func test_escPopsBack_whenNoSelectableContentInDetail() throws {
    let size = Size(width: 40, height: 8)
    let node = buildRootNode(
      NavigationStack {
        NavigationLink("Go", destination: Text("Detail"))
      }
    )

    let (window, control) = try install(node: node, size: size)

    // Push to text-only detail
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    XCTAssertNil(window.firstResponder)
    XCTAssertTrue(render(control: control, size: size).contains("Detail"))

    // Simulate ESC back action (same fallback as Application.performBackAction):
    // when firstResponder is nil, find a selectable element and walk up from it.
    let didPop: Bool
    if window.firstResponder?.performBackAction() == true {
      didPop = true
    } else if let selectable = control.firstSelectableElement {
      didPop = selectable.performBackAction()
    } else {
      didPop = false
    }
    XCTAssertTrue(didPop)
    update(node: node, control: control, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Go"))
    XCTAssertFalse(rendered.contains("Back"))
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

    // Pop via back — back button does not auto-focus; navigate to it
    focusBackButton(window: window, rootControl: control, size: size)
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Go"))
    XCTAssertFalse(rendered.contains("Detail"))
  }

  // MARK: - Nested navigation tests

  func test_nested_navigation_value_push() throws {
    struct NestedNavView: View {
      @State var path = NavigationPath()

      var body: some View {
        NavigationStack(path: $path) {
          VStack {
            NavigationLink("Go", value: 1)
          }
          .navigationDestination(for: Int.self) { value in
            VStack {
              Text("Int: \(value)")
              NavigationLink("Next", value: "hello")
            }
          }
          .navigationDestination(for: String.self) { str in
            Text("String: \(str)")
          }
        }
      }
    }

    let size = Size(width: 40, height: 8)
    let node = buildRootNode(NestedNavView())
    let (window, control) = try install(node: node, size: size)

    // First navigation: push Int value
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered1 = render(control: control, size: size)
    XCTAssertTrue(rendered1.contains("Int: 1"), "Should show Int detail. Got: \(rendered1)")

    // Focus lands on NavigationLink in content after push
    // (back button does not auto-focus)

    // Second navigation: push String value
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered2 = render(control: control, size: size)
    XCTAssertTrue(
      rendered2.contains("String: hello"), "Should show String detail. Got: \(rendered2)")
  }

  func test_nested_navigation_direct_path_push() throws {
    struct NestedNavView: View {
      @State var path = NavigationPath()

      var body: some View {
        NavigationStack(path: $path) {
          VStack {
            NavigationLink("Go", value: 1)
          }
          .navigationDestination(for: Int.self) { value in
            VStack {
              Text("Int: \(value)")
              NavigationLink("Next", value: "hello")
            }
          }
          .navigationDestination(for: String.self) { str in
            Text("String: \(str)")
          }
        }
      }
    }

    let size = Size(width: 40, height: 8)
    let view = NestedNavView()
    let node = buildRootNode(view)
    let (_, control) = try install(node: node, size: size)

    // Directly manipulate the @State path by accessing its node state
    // First find NestedNavView's node
    let nestedNode = node.children[0]  // VStack wrapping -> NestedNavView ComposedView
    // Push first value
    var path = NavigationPath()
    path.append(1)
    nestedNode.state["_path"] = path
    update(node: node, control: control, size: size)

    let rendered1 = render(control: control, size: size)
    XCTAssertTrue(rendered1.contains("Int: 1"), "After first push. Got: \(rendered1)")

    // Push second value
    path.append("hello")
    nestedNode.state["_path"] = path
    update(node: node, control: control, size: size)

    let rendered2 = render(control: control, size: size)
    XCTAssertTrue(rendered2.contains("String: hello"), "After second push. Got: \(rendered2)")
  }

  // MARK: - Nested NavigationStack tests

  func test_nested_navigationStack_no_crash_on_inner_push() throws {
    // Regression: pushing inside a nested NavigationStack used to crash with
    // "Attempting to modify @State variable before view is instantiated"
    // because firstResponder pointed to a stale (removed) control whose
    // @State node had been deallocated.
    struct InnerView: View {
      var body: some View {
        NavigationStack {
          NavigationLink("Deep", destination: Text("Deep detail"))
        }
      }
    }

    let size = Size(width: 40, height: 8)
    let node = buildRootNode(
      NavigationStack {
        NavigationLink(destination: InnerView()) {
          Text("Go")
        }
      }
    )

    let (window, control) = try install(node: node, size: size)

    // Push to inner view
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size, window: window)

    let rendered1 = render(control: control, size: size)
    XCTAssertTrue(rendered1.contains("Deep"), "Should show inner nav content. Got: \(rendered1)")

    // Push inside the inner NavigationStack — this used to crash
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size, window: window)

    let rendered2 = render(control: control, size: size)
    XCTAssertTrue(
      rendered2.contains("Deep detail"), "Should show deep detail. Got: \(rendered2)")
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

  private func update(node: Node, control: Control, size: Size, window: Window? = nil) {
    node.update(using: node.view)
    // Mirror Application.update(): clear stale firstResponder after tree rebuild
    if let window, let fr = window.firstResponder, fr.root !== control {
      fr.resignFirstResponder()
      window.firstResponder = nil
    }
    if let window, window.firstResponder == nil {
      window.firstResponder = control.firstDefaultFocusElement
      window.firstResponder?.becomeFirstResponder()
    }
    control.layout(size: size)
  }

  private func focusBackButton(window: Window, rootControl: Control, size: Size) {
    // When firstResponder is nil (e.g. detail has no selectable content),
    // find the back button via firstSelectableElement on the root.
    let target: Control?
    if let responder = window.firstResponder {
      target = responder.selectableElement(below: 0)
    } else {
      target = rootControl.firstSelectableElement
    }
    guard let target else { return }
    window.firstResponder?.resignFirstResponder()
    window.firstResponder = target
    target.becomeFirstResponder()
    rootControl.layout(size: size)
  }

  private func moveDown(window: Window, rootControl: Control, size: Size) {
    guard let next = window.firstResponder?.selectableElement(below: 0) else { return }
    window.firstResponder?.resignFirstResponder()
    window.firstResponder = next
    window.firstResponder?.becomeFirstResponder()
    rootControl.layout(size: size)
  }

  private func moveUp(window: Window, rootControl: Control, size: Size) {
    guard let next = window.firstResponder?.selectableElement(above: 0) else { return }
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
