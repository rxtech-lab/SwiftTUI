import Foundation

public struct List<Content: View>: View, PrimitiveView, LayoutRootView {
  public let content: Content

  private let getSelection: (() -> AnyHashable?)?
  private let setSelection: ((AnyHashable?) -> Void)?
  private let explicitRowTag: ((Int) -> AnyHashable?)?

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
    self.getSelection = nil
    self.setSelection = nil
    self.explicitRowTag = nil
  }

  public init<SelectionValue: Hashable>(
    selection: Binding<SelectionValue?>,
    @ViewBuilder _ content: () -> Content
  ) {
    self.content = content()
    self.getSelection = {
      guard let value = selection.wrappedValue else { return nil }
      return AnyHashable(value)
    }
    self.setSelection = { selection.wrappedValue = $0 as? SelectionValue }
    self.explicitRowTag = nil
  }

  public init<Data, RowContent>(
    _ data: Data,
    selection: Binding<Data.Element.ID?>,
    @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  )
  where
    Data: RandomAccessCollection,
    Data.Element: Identifiable,
    Content == ForEach<Data, Data.Element.ID, RowContent>
  {
    self.content = ForEach(data, id: \.id, content: rowContent)
    self.getSelection = {
      guard let value = selection.wrappedValue else { return nil }
      return AnyHashable(value)
    }
    self.setSelection = { selection.wrappedValue = $0 as? Data.Element.ID }
    self.explicitRowTag = { row in
      guard row >= 0 && row < data.count else { return nil }
      let index = data.index(data.startIndex, offsetBy: row)
      return AnyHashable(data[index].id)
    }
  }

  static var size: Int? { 1 }

  func buildNode(_ node: Node) {
    node.addNode(at: 0, Node(view: content.view))
    let control = ListControl()
    configure(control: control, node: node)
    node.control = control
  }

  func updateNode(_ node: Node) {
    node.view = self
    let control = node.control as! ListControl
    configure(control: control, node: node)
    node.children[0].update(using: content.view)
    control.didUpdateView()
  }

  func loadData(node: Node) {
    (node.control as! ListControl).reloadData()
  }

  func insertControl(at index: Int, node: Node) {
    (node.control as! ListControl).dataDidChange(at: index)
  }

  func removeControl(at index: Int, node: Node) {
    (node.control as! ListControl).dataDidChange(at: index)
  }

  private func configure(control: ListControl, node: Node) {
    control.rowCountProvider = { node.children[0].size }
    control.rowControlProvider = { node.children[0].control(at: $0) }
    control.selectionGetter = getSelection
    control.selectionSetter = setSelection
    control.explicitRowTagProvider = explicitRowTag
  }

  private final class ListControl: Control {
    override var toolbarHelpText: String? {
      "↑/↓ Move • ←/→ Row • Enter Select"
    }

    var rowCountProvider: (() -> Int)?
    var rowControlProvider: ((Int) -> Control)?
    var selectionGetter: (() -> AnyHashable?)?
    var selectionSetter: ((AnyHashable?) -> Void)?
    var explicitRowTagProvider: ((Int) -> AnyHashable?)?

    private var cachedRows: [Int: ListRowControl] = [:]
    private var realizedRowIndices: [Int] = []

    private var scrollOffset = 0
    private var viewportHeight = 1
    private var selectedTag: AnyHashable?

    private var needsRealization = true
    private let overscan = 1

    override func size(proposedSize: Size) -> Size {
      proposedSize
    }

    override func layout(size: Size) {
      super.layout(size: size)
      let newViewportHeight = max(1, intValue(for: size.height, fallback: max(totalRows, 1)))
      if newViewportHeight != viewportHeight {
        viewportHeight = newViewportHeight
        needsRealization = true
      }
      clampScrollOffset()
      syncSelectionFromBinding()
      realizeRowsIfNeeded(force: false)
      positionRealizedRows(width: size.width)
    }

    override func scroll(to position: Position) {
      let destination = intValue(for: position.line, fallback: 0)
      guard viewportHeight > 0 else { return }

      var updatedOffset = scrollOffset
      if destination < 0 {
        updatedOffset += destination
      } else if destination >= viewportHeight {
        updatedOffset += destination - viewportHeight + 1
      }

      updateScrollOffset(updatedOffset)
      super.scroll(to: position)
    }

    override func selectableElement(below index: Int) -> Control? {
      let startRow = rowIndex(fromChildIndex: index) ?? (scrollOffset - 1)
      var row = startRow + 1
      while row < totalRows {
        ensureRowIsVisible(row)
        if let element = cachedRows[row]?.firstSelectableElement {
          return element
        }
        row += 1
      }
      return super.selectableElement(below: index)
    }

    override func selectableElement(above index: Int) -> Control? {
      let startRow = rowIndex(fromChildIndex: index) ?? min(scrollOffset, totalRows - 1)
      var row = startRow - 1
      while row >= 0 {
        ensureRowIsVisible(row)
        if let element = cachedRows[row]?.firstSelectableElement {
          return element
        }
        row -= 1
      }
      return super.selectableElement(above: index)
    }

    override func didBecomeFirstResponder(descendant: Control) {
      if let row = row(containing: descendant), let tag = row.rowTag {
        setSelectedTag(tag, updateBinding: true)
      }
      super.didBecomeFirstResponder(descendant: descendant)
    }

    func reloadData() {
      needsRealization = true
      realizeRowsIfNeeded(force: true)
    }

    func dataDidChange(at _: Int) {
      removeAllRealizedRows()
      cachedRows.removeAll()
      needsRealization = true
      clampScrollOffset()
      realizeRowsIfNeeded(force: true)
    }

    func didUpdateView() {
      needsRealization = true
      syncSelectionFromBinding()
      realizeRowsIfNeeded(force: true)
    }

    private var totalRows: Int {
      rowCountProvider?() ?? 0
    }

    private func updateScrollOffset(_ value: Int) {
      let clamped = max(0, min(value, max(totalRows - viewportHeight, 0)))
      guard clamped != scrollOffset else { return }
      scrollOffset = clamped
      needsRealization = true
      realizeRowsIfNeeded(force: true)
      positionRealizedRows(width: layer.frame.size.width)
      layer.invalidate()
    }

    private func ensureRowIsVisible(_ row: Int) {
      guard row >= 0 && row < totalRows else { return }
      var updatedOffset = scrollOffset
      if row < updatedOffset {
        updatedOffset = row
      } else if row >= updatedOffset + viewportHeight {
        updatedOffset = row - viewportHeight + 1
      }
      updateScrollOffset(updatedOffset)
    }

    private func realizeRowsIfNeeded(force: Bool) {
      guard force || needsRealization else { return }

      let total = totalRows
      guard total > 0 else {
        removeAllRealizedRows()
        needsRealization = false
        return
      }

      let visibleStart = max(0, scrollOffset - overscan)
      let visibleEnd = min(total - 1, scrollOffset + viewportHeight - 1 + overscan)
      let target = Array(visibleStart...visibleEnd)
      let targetSet = Set(target)

      for row in realizedRowIndices.reversed() where !targetSet.contains(row) {
        unrealizeRow(row)
      }

      for row in target where !realizedRowIndices.contains(row) {
        realizeRow(row)
      }

      refreshRowMetadata()
      needsRealization = false
      layer.invalidate()
    }

    private func realizeRow(_ row: Int) {
      guard row >= 0 && row < totalRows else { return }

      let listRow = cachedRows[row] ?? buildListRow(row)
      cachedRows[row] = listRow

      let insertionPoint =
        realizedRowIndices.firstIndex(where: { $0 > row }) ?? realizedRowIndices.count
      addSubview(listRow, at: insertionPoint)
      realizedRowIndices.insert(row, at: insertionPoint)
    }

    private func unrealizeRow(_ row: Int) {
      guard let position = realizedRowIndices.firstIndex(of: row) else { return }
      removeSubview(at: position)
      realizedRowIndices.remove(at: position)
    }

    private func removeAllRealizedRows() {
      while let row = realizedRowIndices.last {
        unrealizeRow(row)
      }
    }

    private func buildListRow(_ row: Int) -> ListRowControl {
      guard let rowControlProvider else {
        fatalError("List control data source was not configured")
      }
      let contentControl = rowControlProvider(row)
      let listRow = ListRowControl(contentControl: contentControl)
      listRow.rowTag = resolveTag(for: contentControl, row: row)
      listRow.highlighted = isRowSelected(listRow)
      return listRow
    }

    private func resolveTag(for control: Control, row: Int) -> AnyHashable? {
      if let explicit = explicitRowTagProvider?(row) {
        return explicit
      }
      return findTag(in: control)
    }

    private func findTag(in control: Control) -> AnyHashable? {
      if let selectionTag = control.selectionTag {
        return selectionTag
      }
      for child in control.children {
        if let tag = findTag(in: child) {
          return tag
        }
      }
      return nil
    }

    private func refreshRowMetadata() {
      for row in realizedRowIndices {
        guard let listRow = cachedRows[row] else { continue }
        listRow.rowTag = resolveTag(for: listRow.contentControl, row: row)
        listRow.highlighted = isRowSelected(listRow)
      }
    }

    private func isRowSelected(_ row: ListRowControl) -> Bool {
      guard let rowTag = row.rowTag else { return false }
      return rowTag == selectedTag
    }

    private func setSelectedTag(_ tag: AnyHashable?, updateBinding: Bool) {
      guard selectedTag != tag else { return }
      selectedTag = tag
      if updateBinding {
        selectionSetter?(tag)
      }
      refreshRowHighlights()
    }

    private func syncSelectionFromBinding() {
      guard let selectionGetter else { return }
      let externalValue = selectionGetter()
      guard externalValue != selectedTag else { return }
      selectedTag = externalValue
      refreshRowHighlights()
    }

    private func refreshRowHighlights() {
      for row in realizedRowIndices {
        guard let listRow = cachedRows[row] else { continue }
        listRow.highlighted = isRowSelected(listRow)
      }
    }

    private func row(containing control: Control) -> ListRowControl? {
      for rowIndex in realizedRowIndices {
        guard let row = cachedRows[rowIndex] else { continue }
        if control === row || control.isDescendant(of: row) {
          return row
        }
      }
      return nil
    }

    private func rowIndex(fromChildIndex index: Int) -> Int? {
      guard index >= 0 && index < realizedRowIndices.count else { return nil }
      return realizedRowIndices[index]
    }

    private func positionRealizedRows(width: Extended) {
      for row in realizedRowIndices {
        guard let listRow = cachedRows[row] else { continue }
        listRow.layout(size: Size(width: width, height: 1))
        listRow.layer.frame.position = Position(column: 0, line: Extended(row - scrollOffset))
      }
    }

    private func clampScrollOffset() {
      let maxOffset = max(0, totalRows - viewportHeight)
      let clamped = max(0, min(scrollOffset, maxOffset))
      if clamped != scrollOffset {
        scrollOffset = clamped
        needsRealization = true
      }
    }

    private func intValue(for value: Extended, fallback: Int) -> Int {
      if value == .infinity {
        return fallback
      }
      return value.intValue
    }
  }

  private final class ListRowControl: Control {
    let contentControl: Control
    var rowTag: AnyHashable?

    private weak var listRowLayer: ListRowLayer?

    var highlighted: Bool {
      get { listRowLayer?.highlighted ?? false }
      set {
        guard listRowLayer?.highlighted != newValue else { return }
        listRowLayer?.highlighted = newValue
        layer.invalidate()
      }
    }

    init(contentControl: Control) {
      self.contentControl = contentControl
      super.init()
      addSubview(contentControl, at: 0)
    }

    override func size(proposedSize: Size) -> Size {
      let childSize = contentControl.size(proposedSize: Size(width: proposedSize.width, height: 1))
      return Size(width: childSize.width, height: 1)
    }

    override func layout(size: Size) {
      super.layout(size: size)
      contentControl.layout(size: Size(width: size.width, height: 1))
    }

    override func makeLayer() -> Layer {
      let layer = ListRowLayer()
      listRowLayer = layer
      return layer
    }

    private final class ListRowLayer: Layer {
      var highlighted = false

      override func cell(at position: Position) -> Cell? {
        var cell = super.cell(at: position)
        if highlighted {
          cell?.attributes.inverted.toggle()
        }
        return cell
      }
    }
  }
}
