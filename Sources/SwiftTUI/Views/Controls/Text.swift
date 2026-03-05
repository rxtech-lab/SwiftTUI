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
            if proposedSize.width == .infinity || proposedSize.width >= Extended(count) {
                return Size(width: Extended(count), height: 1)
            }
            let width = max(1, proposedSize.width.intValue)
            let lines = computeWrappedLines(width: width)
            let maxLineWidth = lines.map(\.length).max() ?? 0
            return Size(width: Extended(maxLineWidth), height: Extended(lines.count))
        }
        
        override func cell(at position: Position) -> Cell? {
            let count = characterCount
            guard count > 0 else { return nil }
            
            let frameWidth = layer.frame.size.width
            let lines: [WrappedLine]
            
            if frameWidth == .infinity || frameWidth >= Extended(count) {
                lines = [WrappedLine(startOffset: 0, length: count)]
            } else {
                lines = computeWrappedLines(width: max(1, frameWidth.intValue))
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
                let char = attributedText[i ..< characters.index(after: i)]
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
            guard totalCount > width else {
                return [WrappedLine(startOffset: 0, length: totalCount)]
            }
            
            let chars = Array(textForWrapping)
            var lines: [WrappedLine] = []
            var lineStart = 0
            
            while lineStart < chars.count {
                let remaining = chars.count - lineStart
                if remaining <= width {
                    lines.append(WrappedLine(startOffset: lineStart, length: remaining))
                    break
                }
                
                // Check if there's a space right at the width boundary
                if chars[lineStart + width] == " " {
                    lines.append(WrappedLine(startOffset: lineStart, length: width))
                    lineStart += width + 1
                    continue
                }
                
                // Search backwards for a space within the line to break at word boundary
                var breakAt: Int? = nil
                for i in stride(from: lineStart + width - 1, through: lineStart, by: -1) {
                    if chars[i] == " " {
                        breakAt = i
                        break
                    }
                }
                
                if let breakAt {
                    lines.append(WrappedLine(startOffset: lineStart, length: breakAt - lineStart))
                    lineStart = breakAt + 1
                } else {
                    // No space found, break at character boundary
                    lines.append(WrappedLine(startOffset: lineStart, length: width))
                    lineStart += width
                    // Skip leading spaces after character break
                    while lineStart < chars.count && chars[lineStart] == " " {
                        lineStart += 1
                    }
                }
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
