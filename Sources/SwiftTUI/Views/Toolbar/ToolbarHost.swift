import Foundation

struct ToolbarHost<Content: View>: View, PrimitiveView {
  let content: Content
  let showBackButton: Bool
  let onBack: (() -> Bool)?

  init(content: Content, showBackButton: Bool = false, onBack: (() -> Bool)? = nil) {
    self.content = content
    self.showBackButton = showBackButton
    self.onBack = onBack
  }

  static var size: Int? { 1 }

  func buildNode(_ node: Node) {
    node.addNode(at: 0, Node(view: VStack(content: content).view))
    let contentControl = node.children[0].control(at: 0)
    node.control = ToolbarHostControl(
      contentControl: contentControl,
      showBackButton: showBackButton,
      onBack: onBack
    )
  }

  func updateNode(_ node: Node) {
    node.view = self
    node.children[0].update(using: VStack(content: content).view)
    let control = node.control as! ToolbarHostControl
    control.update(
      contentControl: node.children[0].control(at: 0),
      showBackButton: showBackButton,
      onBack: onBack
    )
  }
}

private final class ToolbarHostControl: Control {
  private var contentControl: Control
  private let toolbarRowControl = ToolbarRowControl()

  private var showBackButton: Bool
  private var onBack: (() -> Bool)?

  init(contentControl: Control, showBackButton: Bool, onBack: (() -> Bool)?) {
    self.contentControl = contentControl
    self.showBackButton = showBackButton
    self.onBack = onBack

    super.init()

    addSubview(contentControl, at: 0)
    addSubview(toolbarRowControl, at: 1)
    rebuildToolbar()
  }

  func update(contentControl: Control, showBackButton: Bool, onBack: (() -> Bool)?) {
    if self.contentControl !== contentControl {
      removeSubview(at: 0)
      self.contentControl = contentControl
      addSubview(contentControl, at: 0)
    }

    self.showBackButton = showBackButton
    self.onBack = onBack

    rebuildToolbar()
    layer.invalidate()
  }

  override func size(proposedSize: Size) -> Size {
    let contentSize = contentControl.size(proposedSize: proposedSize)

    let width: Extended
    if proposedSize.width == .infinity {
      width = contentSize.width
    } else {
      width = proposedSize.width
    }

    let height: Extended
    if proposedSize.height == .infinity {
      height = max(contentSize.height + 1, 1)
    } else {
      height = max(proposedSize.height, 1)
    }

    return Size(width: width, height: height)
  }

  override func layout(size: Size) {
    super.layout(size: size)

    let contentHeight = max(size.height - 1, 0)

    contentControl.layout(size: Size(width: size.width, height: contentHeight))
    contentControl.layer.frame.position = .zero

    toolbarRowControl.layout(size: Size(width: size.width, height: 1))
    toolbarRowControl.layer.frame.position = Position(column: 0, line: contentHeight)
  }

  override func selectableElement(below index: Int) -> Control? {
    if index == 0 {
      return toolbarRowControl.firstSelectableElement ?? super.selectableElement(below: index)
    }
    return super.selectableElement(below: index)
  }

  override func selectableElement(above index: Int) -> Control? {
    if index >= 1 {
      return contentControl.firstSelectableElement ?? super.selectableElement(above: index)
    }
    return super.selectableElement(above: index)
  }

  override func performBackAction() -> Bool {
    if let onBack, onBack() {
      layer.invalidate()
      return true
    }
    return super.performBackAction()
  }

  private func rebuildToolbar() {
    let customEntries = contentControl.toolbarEntriesInSubtree()
    let bucketed = bucketEntries(customEntries)

    let navigationControls: [Control]
    if let customNavigation = bucketed[.navigation], !customNavigation.isEmpty {
      navigationControls = customNavigation.map(buildControl)
    } else if showBackButton {
      navigationControls = [
        ToolbarButtonControl(
          text: "Back",
          action: { [weak self] in
            guard let self else { return }
            if self.onBack?() == true {
              self.layer.invalidate()
            }
          })
      ]
    } else {
      navigationControls = []
    }

    let statusControls: [Control]
    if let customStatus = bucketed[.status], !customStatus.isEmpty {
      statusControls = customStatus.map(buildControl)
    } else if let toolbarHelp = contentControl.toolbarHelpTextInSubtree() {
      statusControls = [ToolbarLabelControl(text: toolbarHelp)]
    } else {
      statusControls = []
    }

    let primaryControls: [Control]
    if let customPrimary = bucketed[.primaryAction], !customPrimary.isEmpty {
      primaryControls = customPrimary.map(buildControl)
    } else {
      primaryControls = []
    }

    toolbarRowControl.update(
      navigation: navigationControls,
      status: statusControls,
      primaryAction: primaryControls
    )
  }

  private func bucketEntries(_ entries: [ToolbarEntry]) -> [ToolbarItemPlacement: [ToolbarEntry]] {
    var bucketed: [ToolbarItemPlacement: [ToolbarEntry]] = [:]
    for entry in entries {
      bucketed[entry.placement, default: []].append(entry)
    }
    return bucketed
  }

  private func buildControl(from entry: ToolbarEntry) -> Control {
    let node = Node(view: entry.view)
    node.build()
    return node.control ?? ToolbarLabelControl(text: "")
  }
}

private final class ToolbarRowControl: Control {
  private let navigationControl = ToolbarPlacementControl()
  private let statusControl = ToolbarPlacementControl()
  private let primaryActionControl = ToolbarPlacementControl()

  override init() {
    super.init()
    addSubview(navigationControl, at: 0)
    addSubview(statusControl, at: 1)
    addSubview(primaryActionControl, at: 2)
  }

  func update(navigation: [Control], status: [Control], primaryAction: [Control]) {
    navigationControl.setControls(navigation)
    statusControl.setControls(status)
    primaryActionControl.setControls(primaryAction)
    layer.invalidate()
  }

  override func size(proposedSize: Size) -> Size {
    Size(width: proposedSize.width, height: 1)
  }

  override func layout(size: Size) {
    super.layout(size: size)

    let navSize = navigationControl.size(proposedSize: Size(width: size.width, height: 1))
    let statusSize = statusControl.size(proposedSize: Size(width: size.width, height: 1))
    let primarySize = primaryActionControl.size(proposedSize: Size(width: size.width, height: 1))

    navigationControl.layout(size: navSize)
    statusControl.layout(size: Size(width: max(statusSize.width, 0), height: 1))
    primaryActionControl.layout(size: primarySize)

    navigationControl.layer.frame.position = .zero

    let primaryColumn = max(size.width - primarySize.width, 0)
    primaryActionControl.layer.frame.position = Position(column: primaryColumn, line: 0)

    let leftBound = navigationControl.layer.frame.size.width + 1
    let rightBound = max(primaryColumn - 1, leftBound)

    var statusWidth = min(statusSize.width, max(rightBound - leftBound + 1, 0))
    if statusWidth < 0 { statusWidth = 0 }

    statusControl.layout(size: Size(width: statusWidth, height: 1))
    let centeredColumn = (size.width - statusWidth) / 2
    let clampedColumn = min(max(centeredColumn, leftBound), rightBound)
    statusControl.layer.frame.position = Position(column: clampedColumn, line: 0)
  }
}

private final class ToolbarPlacementControl: Control {
  func setControls(_ controls: [Control]) {
    while !children.isEmpty {
      removeSubview(at: children.count - 1)
    }
    for (index, control) in controls.enumerated() {
      addSubview(control, at: index)
    }
  }

  override func size(proposedSize: Size) -> Size {
    var width: Extended = 0
    for (index, control) in children.enumerated() {
      let childSize = control.size(
        proposedSize: Size(width: proposedSize.width, height: proposedSize.height))
      width += childSize.width
      if index < children.count - 1 {
        width += 1
      }
    }
    return Size(width: width, height: 1)
  }

  override func layout(size: Size) {
    super.layout(size: size)

    var column: Extended = 0
    for (index, control) in children.enumerated() {
      let childSize = control.size(
        proposedSize: Size(width: max(size.width - column, 0), height: 1))
      control.layout(
        size: Size(width: min(childSize.width, max(size.width - column, 0)), height: 1))
      control.layer.frame.position = Position(column: column, line: 0)
      column += control.layer.frame.size.width
      if index < children.count - 1 {
        column += 1
      }
    }
  }

  override func selectableElement(rightOf index: Int) -> Control? {
    var current = index + 1
    while current < children.count {
      if let element = children[current].firstSelectableElement {
        return element
      }
      current += 1
    }
    return super.selectableElement(rightOf: index)
  }

  override func selectableElement(leftOf index: Int) -> Control? {
    var current = index - 1
    while current >= 0 {
      if let element = children[current].firstSelectableElement {
        return element
      }
      current -= 1
    }
    return super.selectableElement(leftOf: index)
  }
}

private final class ToolbarLabelControl: Control {
  var text: String

  init(text: String) {
    self.text = text
  }

  override func size(proposedSize: Size) -> Size {
    Size(width: Extended(text.count), height: 1)
  }

  override func cell(at position: Position) -> Cell? {
    guard position.line == 0 else { return nil }
    guard position.column.intValue < text.count else { return Cell(char: " ") }
    let index = text.index(text.startIndex, offsetBy: position.column.intValue)
    return Cell(char: text[index])
  }
}

private final class ToolbarButtonControl: Control {
  let text: String
  let action: () -> Void

  init(text: String, action: @escaping () -> Void) {
    self.text = text
    self.action = action
  }

  override var selectable: Bool { true }

  override func size(proposedSize: Size) -> Size {
    Size(width: Extended(text.count), height: 1)
  }

  override func handleEvent(_ char: Character) {
    if char == "\n" || char == " " {
      action()
    }
  }

  override func becomeFirstResponder() {
    super.becomeFirstResponder()
    layer.invalidate()
  }

  override func resignFirstResponder() {
    super.resignFirstResponder()
    layer.invalidate()
  }

  override func cell(at position: Position) -> Cell? {
    guard position.line == 0 else { return nil }
    guard position.column.intValue < text.count else { return Cell(char: " ") }

    let index = text.index(text.startIndex, offsetBy: position.column.intValue)
    return Cell(
      char: text[index],
      attributes: CellAttributes(inverted: isFirstResponder)
    )
  }
}
