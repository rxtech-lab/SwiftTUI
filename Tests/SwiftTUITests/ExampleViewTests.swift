import XCTest

@testable import SwiftTUI

final class ExampleViewTests: XCTestCase {

  // MARK: - Colors example

  func test_colorsExample_rendersTitle() throws {
    struct ColorsView: View {
      var body: some View {
        VStack(alignment: .center, spacing: 3) {
          Text("ANSI Colors")
            .bold()
            .padding(.horizontal, 1)
            .border(style: .double)
          HStack {
            Text("Red").foregroundColor(.red)
            Text("Green").foregroundColor(.green)
            Text("Blue").foregroundColor(.blue)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      }
    }

    let (_, control) = try install(ColorsView(), size: Size(width: 40, height: 12))
    let rendered = render(control: control, size: Size(width: 40, height: 12))

    XCTAssertTrue(rendered.contains("ANSI Colors"))
    XCTAssertTrue(rendered.contains("Red"))
    XCTAssertTrue(rendered.contains("Green"))
    XCTAssertTrue(rendered.contains("Blue"))
  }

  // MARK: - Numbers example

  func test_numbersExample_buttonAddsNumber() throws {
    struct NumbersView: View {
      @State var counter = 1

      var body: some View {
        VStack {
          Button("Add number") { counter += 1 }
          if counter > 1 {
            Button("Remove number") { counter -= 1 }
          }
          ForEach(1...counter, id: \.self) { i in
            Text("Number \(i)")
          }
          .border()
        }
        .padding()
      }
    }

    let size = Size(width: 30, height: 15)
    let node = buildNode(NumbersView())
    let (window, control) = try installNode(node, size: size)
    let rendered = render(control: control, size: size)

    XCTAssertTrue(rendered.contains("Add number"))
    XCTAssertTrue(rendered.contains("Number 1"))
    XCTAssertFalse(rendered.contains("Remove number"))

    // Press Enter on "Add number" button
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)
    let afterAdd = render(control: control, size: size)

    XCTAssertTrue(afterAdd.contains("Number 2"))
    XCTAssertTrue(afterAdd.contains("Remove number"))
  }

  // MARK: - ToDoList example

  func test_todoListExample_rendersAndAcceptsInput() throws {
    struct ToDoListView: View {
      var body: some View {
        VStack {
          Text("To Do")
            .bold()
          TextField(placeholder: "New item") { _ in }
          Button("Add") {}
        }
        .padding()
        .border()
        .background(.blue)
      }
    }

    let size = Size(width: 30, height: 10)
    let (window, control) = try install(ToDoListView(), size: size)
    let rendered = render(control: control, size: size)

    XCTAssertTrue(rendered.contains("To Do"))
    XCTAssertTrue(rendered.contains("Add"))

    // First responder is already the TextField; type into it
    window.firstResponder?.handleEvent("H")
    window.firstResponder?.handleEvent("i")
    control.layout(size: size)
    let afterType = render(control: control, size: size)
    XCTAssertTrue(afterType.contains("Hi"))
  }

  // MARK: - Flags example

  func test_flagsExample_rendersLayout() throws {
    struct FlagsView: View {
      var body: some View {
        VStack {
          HStack(spacing: 0) {
            Text(" ").background(.red)
            Text(" ").background(.white)
            Text(" ").background(.blue)
          }
          .border()
          Text("Flag Editor")
            .bold()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      }
    }

    let size = Size(width: 40, height: 10)
    let (_, control) = try install(FlagsView(), size: size)
    let rendered = render(control: control, size: size)

    XCTAssertTrue(rendered.contains("Flag Editor"))
  }

  // MARK: - JSONPlaceholder example

  func test_jsonPlaceholderExample_navigatesToDetail() throws {
    struct PostListView: View {
      var body: some View {
        NavigationStack {
          VStack {
            Text("Posts").bold()
            Divider()
            List {
              ForEach(1...3, id: \.self) { i in
                NavigationLink("Post \(i)", destination: Text("Detail \(i)"))
              }
            }
          }
        }
      }
    }

    let size = Size(width: 40, height: 10)
    let node = buildNode(PostListView())
    let (window, control) = try installNode(node, size: size)
    let rendered = render(control: control, size: size)

    XCTAssertTrue(rendered.contains("Posts"))
    XCTAssertTrue(rendered.contains("Post 1"))

    // Navigate into a post via NavigationLink
    window.firstResponder?.handleEvent("\n")
    update(node: node, control: control, size: size)
    let detail = render(control: control, size: size)

    XCTAssertTrue(detail.contains("Detail 1"))
    XCTAssertTrue(detail.contains("Back"))
  }

  // MARK: - Helpers

  private func buildNode<V: View>(_ view: V) -> Node {
    let node = Node(view: VStack(content: view).view)
    node.build()
    return node
  }

  private func install<V: View>(_ view: V, size: Size) throws -> (Window, Control) {
    let node = buildNode(view)
    return try installNode(node, size: size)
  }

  private func installNode(_ node: Node, size: Size) throws -> (Window, Control) {
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
