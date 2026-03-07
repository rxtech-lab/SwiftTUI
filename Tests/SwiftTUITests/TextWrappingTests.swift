import XCTest

@testable import SwiftTUI

final class TextWrappingTests: XCTestCase {

  // MARK: - Word wrapping

  func test_textWraps_atWordBoundary() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello World")
        }
      }
    }

    let size = Size(width: 6, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let lines = renderLines(control: control, size: size)

    XCTAssertTrue(lines[0].contains("Hello"))
    XCTAssertTrue(lines[1].contains("World"))
  }

  func test_textWraps_multipleWords() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("one two three")
        }
      }
    }

    let size = Size(width: 7, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let lines = renderLines(control: control, size: size)

    // "one two" fits in width 7, "three" wraps to next line
    XCTAssertTrue(lines[0].contains("one two"))
    XCTAssertTrue(lines[1].contains("three"))
  }

  func test_textWraps_atCharacterBoundary_whenWordTooLong() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("abcdefghij")
        }
      }
    }

    let size = Size(width: 5, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let rendered = render(control: control, size: size)

    XCTAssertTrue(rendered.contains("abcde"))
    XCTAssertTrue(rendered.contains("fghij"))
  }

  func test_textDoesNotWrap_whenWidthSufficient() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello")
        }
      }
    }

    let size = Size(width: 20, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let rendered = render(control: control, size: size)

    XCTAssertTrue(rendered.contains("Hello"))
    // Text should be on a single line, so "Hello" appears intact
    let lines = rendered.split(separator: "\n")
    XCTAssertTrue(lines[0].contains("Hello"))
  }

  func test_textDoesNotWrap_whenWidthExactlyMatchesText() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello")
        }
      }
    }

    // "Hello" is 5 characters, width is 5
    let size = Size(width: 5, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let rendered = render(control: control, size: size)

    let lines = rendered.split(separator: "\n")
    XCTAssertTrue(lines[0].contains("Hello"))
  }

  // MARK: - Size calculation

  func test_wrappedTextSize_height() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello World")
        }
      }
    }

    let node = buildNode(MyView())
    let control = try XCTUnwrap(node.control)
    // "Hello World" is 11 chars; at width 6, wraps to 2 lines
    let textSize = control.size(proposedSize: Size(width: 6, height: 10))
    XCTAssertEqual(textSize.height, 2)
  }

  func test_wrappedTextSize_width() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello World")
        }
      }
    }

    let node = buildNode(MyView())
    let control = try XCTUnwrap(node.control)
    // "Hello World" at width 6 wraps to ["Hello", "World"], max width = 5
    let textSize = control.size(proposedSize: Size(width: 6, height: 10))
    XCTAssertEqual(textSize.width, Extended(5))
  }

  func test_unwrappedTextSize() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello")
        }
      }
    }

    let node = buildNode(MyView())
    let control = try XCTUnwrap(node.control)
    let textSize = control.size(proposedSize: Size(width: 20, height: 10))
    XCTAssertEqual(textSize.width, Extended(5))
    XCTAssertEqual(textSize.height, 1)
  }

  func test_emptyTextSize() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("")
        }
      }
    }

    let node = buildNode(MyView())
    let control = try XCTUnwrap(node.control)
    let textSize = control.size(proposedSize: Size(width: 20, height: 10))
    XCTAssertEqual(textSize.width, Extended(0))
    XCTAssertEqual(textSize.height, 1)
  }

  // MARK: - Rendering correctness

  func test_wrappedText_rendersCorrectCharacters() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("ab cd ef")
        }
      }
    }

    // "ab cd ef" at width 5: ["ab cd", "ef"]
    // Wait: "ab cd" is 5 chars, "ef" is 2 chars
    let size = Size(width: 5, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let lines = renderLines(control: control, size: size)

    XCTAssertEqual(lines[0], "ab cd")
    XCTAssertEqual(lines[1].prefix(2), "ef")
  }

  func test_wrappedText_threeLines() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("aa bb cc dd ee")
        }
      }
    }

    // "aa bb cc dd ee" at width 5:
    // chars[5]=' ' → line 1 = "aa bb", lineStart=6
    // chars[11]=' ' → line 2 = "cc dd", lineStart=12
    // remaining=2 ≤ 5 → line 3 = "ee"
    let size = Size(width: 5, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let lines = renderLines(control: control, size: size)

    XCTAssertEqual(lines[0], "aa bb")
    XCTAssertEqual(lines[1], "cc dd")
    XCTAssertEqual(lines[2].prefix(2), "ee")
  }

  func test_textWraps_inFrame() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello World")
            .frame(maxWidth: 6)
        }
      }
    }

    let size = Size(width: 20, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let rendered = render(control: control, size: size)

    XCTAssertTrue(rendered.contains("Hello"))
    XCTAssertTrue(rendered.contains("World"))
  }

  func test_textWraps_withInfinityWidth_doesNotWrap() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello World")
            .frame(maxWidth: .infinity)
        }
      }
    }

    let size = Size(width: 40, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let rendered = render(control: control, size: size)

    // With infinity width, text should not wrap
    XCTAssertTrue(rendered.contains("Hello World"))
  }

  func test_multipleTexts_inVStack_withWrapping() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello World")
          Text("Goodbye")
        }
      }
    }

    let size = Size(width: 7, height: 10)
    let (_, control) = try install(MyView(), size: size)
    let rendered = render(control: control, size: size)

    XCTAssertTrue(rendered.contains("Hello"))
    XCTAssertTrue(rendered.contains("World"))
    XCTAssertTrue(rendered.contains("Goodbye"))
  }

  // MARK: - Newline handling

  func test_textSplitsOnNewline() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Line1\nLine2\nLine3")
        }
      }
    }

    let size = Size(width: 20, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let lines = renderLines(control: control, size: size)

    XCTAssertTrue(lines[0].contains("Line1"), "First line should contain 'Line1'. Got: \(lines[0])")
    XCTAssertTrue(
      lines[1].contains("Line2"), "Second line should contain 'Line2'. Got: \(lines[1])")
    XCTAssertTrue(lines[2].contains("Line3"), "Third line should contain 'Line3'. Got: \(lines[2])")
  }

  func test_textNewline_sizeIncludesAllLines() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("AB\nCD")
        }
      }
    }

    let size = Size(width: 20, height: 5)
    let (_, control) = try install(MyView(), size: size)
    let lines = renderLines(control: control, size: size)

    XCTAssertTrue(lines[0].contains("AB"))
    XCTAssertTrue(lines[1].contains("CD"))
    // Ensure newline character itself is NOT rendered
    XCTAssertFalse(lines[0].contains("\n"))
  }

  func test_textNewline_doesNotRenderNewlineCharacter() throws {
    struct MyView: View {
      var body: some View {
        VStack {
          Text("Hello\nWorld")
        }
      }
    }

    let size = Size(width: 40, height: 5)
    let (_, control) = try install(MyView(), size: size)

    // Check that no cell returns a newline character
    for line in 0..<5 {
      for col in 0..<40 {
        let cell = control.layer.cell(at: Position(column: Extended(col), line: Extended(line)))
        if let cell {
          XCTAssertNotEqual(cell.char, "\n", "Cell at (\(col), \(line)) should not contain newline")
        }
      }
    }
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

  private func render(control: Control, size: Size) -> String {
    (0..<size.height.intValue)
      .map { line(control: control, width: size.width.intValue, line: $0) }
      .joined(separator: "\n")
  }

  private func renderLines(control: Control, size: Size) -> [String] {
    (0..<size.height.intValue)
      .map { line(control: control, width: size.width.intValue, line: $0) }
  }

  private func line(control: Control, width: Int, line: Int) -> String {
    guard width > 0 else { return "" }
    return (0..<width).map { column in
      control.layer.cell(at: Position(column: Extended(column), line: Extended(line)))?.char ?? " "
    }.map(String.init).joined()
  }
}
