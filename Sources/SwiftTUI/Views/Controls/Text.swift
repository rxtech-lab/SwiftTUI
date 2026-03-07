import Foundation

public struct Text: View, PrimitiveView {
  private var text: String?

  private var _attributedText: Any?

  @available(macOS 12, *)
  private var attributedText: AttributedString? { _attributedText as? AttributedString }

  @Environment(\.foregroundColor) private var foregroundColor: Color
  @Environment(\.bold) private var bold: Bool
  @Environment(\.italic) private var italic: Bool
  @Environment(\.underline) private var underline: Bool
  @Environment(\.strikethrough) private var strikethrough: Bool

  public init(_ text: String) {
    self.text = text
  }

  @available(macOS 12, *)
  public init(_ attributedText: AttributedString) {
    self._attributedText = attributedText
  }

  static var size: Int? { 1 }

  func buildNode(_ node: Node) {
    setupEnvironmentProperties(node: node)
    node.control = TextControl(
      text: text,
      attributedText: _attributedText,
      foregroundColor: foregroundColor,
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough
    )
  }

  func updateNode(_ node: Node) {
    setupEnvironmentProperties(node: node)
    node.view = self
    let control = node.control as! TextControl
    control.text = text
    control._attributedText = _attributedText
    control.foregroundColor = foregroundColor
    control.bold = bold
    control.italic = italic
    control.underline = underline
    control.strikethrough = strikethrough
    control.layer.invalidate()
  }

  private class TextControl: Control {
    var text: String?

    var _attributedText: Any?

    @available(macOS 12, *)
    var attributedText: AttributedString? { _attributedText as? AttributedString }

    var foregroundColor: Color
    var bold: Bool
    var italic: Bool
    var underline: Bool
    var strikethrough: Bool

    init(
      text: String?,
      attributedText: Any?,
      foregroundColor: Color,
      bold: Bool,
      italic: Bool,
      underline: Bool,
      strikethrough: Bool
    ) {
      self.text = text
      self._attributedText = attributedText
      self.foregroundColor = foregroundColor
      self.bold = bold
      self.italic = italic
      self.underline = underline
      self.strikethrough = strikethrough
    }

    override func size(proposedSize: Size) -> Size {
      let count = characterCount
      guard count > 0 else {
        return Size(width: 0, height: 1)
      }
      let hasNewlines = textForWrapping.contains("\n")
      if !hasNewlines && (proposedSize.width == .infinity || proposedSize.width >= Extended(count))
      {
        return Size(width: Extended(count), height: 1)
      }
      let width: Int
      if proposedSize.width == .infinity {
        width = count
      } else {
        width = max(1, proposedSize.width.intValue)
      }
      let lines = computeWrappedLines(width: width)
      let maxLineWidth = lines.map(\.length).max() ?? 0
      return Size(width: Extended(maxLineWidth), height: Extended(lines.count))
    }

    override func cell(at position: Position) -> Cell? {
      let count = characterCount
      guard count > 0 else { return nil }

      let frameWidth = layer.frame.size.width
      let lines: [WrappedLine]
      let hasNewlines = textForWrapping.contains("\n")

      if !hasNewlines && (frameWidth == .infinity || frameWidth >= Extended(count)) {
        lines = [WrappedLine(startOffset: 0, length: count)]
      } else {
        let width: Int
        if frameWidth == .infinity {
          width = count
        } else {
          width = max(1, frameWidth.intValue)
        }
        lines = computeWrappedLines(width: width)
      }

      let lineIndex = position.line.intValue
      guard lineIndex >= 0, lineIndex < lines.count else { return nil }
      let wrappedLine = lines[lineIndex]

      let colIndex = position.column.intValue
      guard colIndex >= 0, colIndex < wrappedLine.length else { return .init(char: " ") }

      let charIndex = wrappedLine.startOffset + colIndex

      if #available(macOS 12, *), let attributedText {
        let characters = attributedText.characters
        let i = characters.index(characters.startIndex, offsetBy: charIndex)
        let char = attributedText[i..<characters.index(after: i)]
        let cellAttributes = CellAttributes(
          bold: char.bold ?? bold,
          italic: char.italic ?? italic,
          underline: char.underline ?? underline,
          strikethrough: char.strikethrough ?? strikethrough,
          inverted: char.inverted ?? false
        )
        return Cell(
          char: char.characters[char.startIndex],
          foregroundColor: char.foregroundColor ?? foregroundColor,
          backgroundColor: char.backgroundColor,
          attributes: cellAttributes
        )
      }
      if let text {
        let cellAttributes = CellAttributes(
          bold: bold,
          italic: italic,
          underline: underline,
          strikethrough: strikethrough
        )
        return Cell(
          char: text[text.index(text.startIndex, offsetBy: charIndex)],
          foregroundColor: foregroundColor,
          attributes: cellAttributes
        )
      }
      return nil
    }

    // MARK: - Text wrapping

    private struct WrappedLine {
      let startOffset: Int
      let length: Int
    }

    private func computeWrappedLines(width: Int) -> [WrappedLine] {
      let totalCount = characterCount
      guard width > 0, totalCount > 0 else { return [] }

      let chars = Array(textForWrapping)
      var lines: [WrappedLine] = []
      var lineStart = 0

      while lineStart < chars.count {
        // Find the next hard newline within the remaining text
        let searchEnd = chars.count
        var newlineIndex: Int? = nil
        for i in lineStart..<searchEnd {
          if chars[i] == "\n" {
            newlineIndex = i
            break
          }
        }

        // The segment up to the newline (or end of text)
        let segmentEnd = newlineIndex ?? chars.count
        let segmentLength = segmentEnd - lineStart

        if segmentLength == 0 {
          // Empty line from consecutive newlines
          lines.append(WrappedLine(startOffset: lineStart, length: 0))
          lineStart = segmentEnd + 1
          continue
        }

        // Word-wrap this segment within the given width
        var segStart = lineStart
        while segStart < segmentEnd {
          let remaining = segmentEnd - segStart
          if remaining <= width {
            lines.append(WrappedLine(startOffset: segStart, length: remaining))
            segStart = segmentEnd
            break
          }

          // Check if there's a space right at the width boundary
          if chars[segStart + width] == " " {
            lines.append(WrappedLine(startOffset: segStart, length: width))
            segStart += width + 1
            continue
          }

          // Search backwards for a space within the line to break at word boundary
          var spaceIndex: Int? = nil
          for i in stride(from: segStart + width - 1, through: segStart, by: -1) {
            if chars[i] == " " {
              spaceIndex = i
              break
            }
          }

          if let spaceIndex {
            lines.append(WrappedLine(startOffset: segStart, length: spaceIndex - segStart))
            segStart = spaceIndex + 1
          } else {
            // No space found, break at character boundary
            lines.append(WrappedLine(startOffset: segStart, length: width))
            segStart += width
          }
        }

        // Skip past the newline character
        if newlineIndex != nil {
          lineStart = segmentEnd + 1
        } else {
          break
        }
      }

      // Trailing newline produces an empty line
      if !chars.isEmpty && chars.last == "\n" {
        lines.append(WrappedLine(startOffset: chars.count, length: 0))
      }

      return lines
    }

    private var textForWrapping: String {
      if let text { return text }
      if #available(macOS 12, *), let attributedText {
        return String(attributedText.characters)
      }
      return ""
    }

    private var characterCount: Int {
      if #available(macOS 12, *), let attributedText {
        return attributedText.characters.count
      }
      return text?.count ?? 0
    }
  }
}
