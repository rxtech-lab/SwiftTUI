import XCTest

@testable import SwiftTUI

private class FakeContent: LayerDrawing {
  var width: Int
  var height: Int
  var char: Character

  init(width: Int, height: Int, char: Character) {
    self.width = width
    self.height = height
    self.char = char
  }

  func cell(at position: Position) -> Cell? {
    let col = position.column.intValue
    let line = position.line.intValue
    guard col >= 0, col < width, line >= 0, line < height else { return nil }
    return Cell(char: char, foregroundColor: .default, backgroundColor: .default)
  }
}

final class RendererTests: XCTestCase {
  func test_renderer_clears_stale_cells_when_content_removed() {
    let root = Layer()
    root.frame = Rect(position: .zero, size: Size(width: 10, height: 2))

    let child = Layer()
    child.frame = Rect(position: .zero, size: Size(width: 5, height: 1))
    let content = FakeContent(width: 5, height: 1, char: "X")
    child.content = content

    root.addLayer(child, at: 0)

    let renderer = Renderer(layer: root)
    renderer.draw()

    let pos00 = Position(column: 0, line: 0)
    XCTAssertEqual(renderer.cacheCell(at: pos00)?.char, "X")

    // Remove the child — positions now return nil
    root.removeLayer(at: 0)

    root.invalidated = Rect(position: .zero, size: Size(width: 5, height: 1))
    renderer.update()

    let cell = renderer.cacheCell(at: pos00)
    XCTAssertNotNil(cell, "Position should have been redrawn with blank cell")
    XCTAssertEqual(cell?.char, " ", "Stale 'X' should be replaced with blank space")
  }

  func test_renderer_clears_cells_when_child_shrinks() {
    let root = Layer()
    root.frame = Rect(position: .zero, size: Size(width: 10, height: 2))

    let child = Layer()
    child.frame = Rect(position: .zero, size: Size(width: 8, height: 1))
    let content = FakeContent(width: 8, height: 1, char: "A")
    child.content = content

    root.addLayer(child, at: 0)

    let renderer = Renderer(layer: root)
    renderer.draw()

    let pos5 = Position(column: 5, line: 0)
    XCTAssertEqual(renderer.cacheCell(at: pos5)?.char, "A")

    // Shrink child from width 8 to width 3
    child.frame = Rect(position: .zero, size: Size(width: 3, height: 1))
    content.width = 3

    root.invalidated = Rect(position: .zero, size: Size(width: 8, height: 1))
    renderer.update()

    let cell = renderer.cacheCell(at: pos5)
    XCTAssertNotNil(cell)
    XCTAssertEqual(cell?.char, " ", "Position outside shrunk child should be cleared")

    let pos1 = Position(column: 1, line: 0)
    XCTAssertEqual(renderer.cacheCell(at: pos1)?.char, "A")
  }
}
