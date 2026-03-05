import XCTest

@testable import SwiftTUI

final class ToolbarTests: XCTestCase {
  func test_listHelp_appearsWhenListIsVisible() throws {
    let size = Size(width: 80, height: 10)
    let node = buildRootNode(
      NavigationStack {
        List {
          Button("Row", action: {})
        }
      }
    )

    let (_, control) = try install(node: node, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("↑/↓ Move"))
    XCTAssertTrue(rendered.contains("←/→ Row"))
    XCTAssertTrue(rendered.contains("Enter Select"))
  }

  func test_customStatus_replacesAutoListHelp() throws {
    let size = Size(width: 80, height: 10)
    let node = buildRootNode(
      NavigationStack {
        List {
          Button("Row", action: {})
        }
        .toolbar {
          ToolbarItem(placement: .status) {
            Text("Custom Status")
          }
        }
      }
    )

    let (_, control) = try install(node: node, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Custom Status"))
    XCTAssertFalse(rendered.contains("Enter Select"))
  }

  func test_customPrimary_keepsAutoListHelp() throws {
    let size = Size(width: 80, height: 10)
    let node = buildRootNode(
      NavigationStack {
        List {
          Button("Row", action: {})
        }
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Text("Action")
          }
        }
      }
    )

    let (_, control) = try install(node: node, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Enter Select"))
    XCTAssertTrue(rendered.contains("Action"))
  }

  func test_customNavigation_replacesAutoBackButtonWhenPushed() throws {
    struct Destination: View {
      var body: some View {
        Text("Detail")
          .toolbar {
            ToolbarItem(placement: .navigation) {
              Text("Custom Nav")
            }
          }
      }
    }

    let size = Size(width: 80, height: 10)
    let node = buildRootNode(
      NavigationStack {
        NavigationLink("Go", destination: Destination())
      }
    )

    let (window, control) = try install(node: node, size: size)

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Custom Nav"))
    XCTAssertFalse(rendered.contains("Back"))
  }

  func test_customStatus_doesNotReplaceBackPlacement() throws {
    struct Destination: View {
      var body: some View {
        Text("Detail")
          .toolbar {
            ToolbarItem(placement: .status) {
              Text("Status")
            }
          }
      }
    }

    let size = Size(width: 80, height: 10)
    let node = buildRootNode(
      NavigationStack {
        NavigationLink("Go", destination: Destination())
      }
    )

    let (window, control) = try install(node: node, size: size)

    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)

    let rendered = render(control: control, size: size)
    XCTAssertTrue(rendered.contains("Back"))
    XCTAssertTrue(rendered.contains("Status"))
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
