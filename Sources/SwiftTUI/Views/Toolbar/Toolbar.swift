import Foundation

public enum ToolbarItemPlacement: Hashable {
  case navigation
  case status
  case primaryAction
}

struct ToolbarEntry {
  let placement: ToolbarItemPlacement
  let view: GenericView
}

private protocol ToolbarEntryProvider {
  func asToolbarEntries() -> [ToolbarEntry]
}

extension View {
  public func toolbar<ToolbarContent: View>(@ViewBuilder _ content: () -> ToolbarContent)
    -> some View
  {
    ToolbarModifier(content: self, toolbarContent: content())
  }
}

private struct ToolbarModifier<Content: View, ToolbarContent: View>: View, PrimitiveView,
  ModifierView
{
  let content: Content
  let toolbarContent: ToolbarContent

  static var size: Int? { Content.size }

  func buildNode(_ node: Node) {
    node.controls = WeakSet<Control>()
    node.addNode(at: 0, Node(view: content.view))
  }

  func updateNode(_ node: Node) {
    node.view = self
    node.children[0].update(using: content.view)
    for control in node.controls?.values ?? [] {
      control.toolbarEntries = extractToolbarEntries(from: toolbarContent)
    }
  }

  func passControl(_ control: Control, node: Node) -> Control {
    control.toolbarEntries = extractToolbarEntries(from: toolbarContent)
    node.controls?.add(control)
    return control
  }

  private func extractToolbarEntries(from content: ToolbarContent) -> [ToolbarEntry] {
    guard let provider = content as? ToolbarEntryProvider else {
      return []
    }
    return provider.asToolbarEntries()
  }
}

public struct ToolbarItem<Content: View>: View, PrimitiveView {
  public let placement: ToolbarItemPlacement
  public let content: Content

  public init(placement: ToolbarItemPlacement, @ViewBuilder content: () -> Content) {
    self.placement = placement
    self.content = content()
  }

  static var size: Int? { 0 }

  func buildNode(_ node: Node) {}

  func updateNode(_ node: Node) {
    node.view = self
  }
}

extension ToolbarItem: ToolbarEntryProvider {
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    [ToolbarEntry(placement: placement, view: HStack { content }.view)]
  }
}

public struct ToolbarItemGroup<Content: View>: View, PrimitiveView {
  public let placement: ToolbarItemPlacement
  public let content: Content

  public init(placement: ToolbarItemPlacement, @ViewBuilder content: () -> Content) {
    self.placement = placement
    self.content = content()
  }

  static var size: Int? { 0 }

  func buildNode(_ node: Node) {}

  func updateNode(_ node: Node) {
    node.view = self
  }
}

extension ToolbarItemGroup: ToolbarEntryProvider {
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    [ToolbarEntry(placement: placement, view: HStack { content }.view)]
  }
}

extension EmptyView: ToolbarEntryProvider {
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    []
  }
}

extension Group: ToolbarEntryProvider where Content: ToolbarEntryProvider {
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.asToolbarEntries()
  }
}

extension Optional: ToolbarEntryProvider where Wrapped: View & ToolbarEntryProvider {
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    switch self {
    case .none:
      return []
    case .some(let wrapped):
      return wrapped.asToolbarEntries()
    }
  }
}

extension _ConditionalView: ToolbarEntryProvider
where TrueContent: ToolbarEntryProvider, FalseContent: ToolbarEntryProvider {
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    switch content {
    case .a(let value):
      return value.asToolbarEntries()
    case .b(let value):
      return value.asToolbarEntries()
    }
  }
}

extension TupleView2: ToolbarEntryProvider
where C0: ToolbarEntryProvider, C1: ToolbarEntryProvider {
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries()
  }
}

extension TupleView3: ToolbarEntryProvider
where C0: ToolbarEntryProvider, C1: ToolbarEntryProvider, C2: ToolbarEntryProvider {
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries() + content.2.asToolbarEntries()
  }
}

extension TupleView4: ToolbarEntryProvider
where
  C0: ToolbarEntryProvider, C1: ToolbarEntryProvider, C2: ToolbarEntryProvider,
  C3: ToolbarEntryProvider
{
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries() + content.2.asToolbarEntries()
      + content.3.asToolbarEntries()
  }
}

extension TupleView5: ToolbarEntryProvider
where
  C0: ToolbarEntryProvider, C1: ToolbarEntryProvider, C2: ToolbarEntryProvider,
  C3: ToolbarEntryProvider, C4: ToolbarEntryProvider
{
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries() + content.2.asToolbarEntries()
      + content.3.asToolbarEntries() + content.4.asToolbarEntries()
  }
}

extension TupleView6: ToolbarEntryProvider
where
  C0: ToolbarEntryProvider, C1: ToolbarEntryProvider, C2: ToolbarEntryProvider,
  C3: ToolbarEntryProvider, C4: ToolbarEntryProvider, C5: ToolbarEntryProvider
{
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries() + content.2.asToolbarEntries()
      + content.3.asToolbarEntries() + content.4.asToolbarEntries() + content.5.asToolbarEntries()
  }
}

extension TupleView7: ToolbarEntryProvider
where
  C0: ToolbarEntryProvider, C1: ToolbarEntryProvider, C2: ToolbarEntryProvider,
  C3: ToolbarEntryProvider, C4: ToolbarEntryProvider, C5: ToolbarEntryProvider,
  C6: ToolbarEntryProvider
{
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries() + content.2.asToolbarEntries()
      + content.3.asToolbarEntries() + content.4.asToolbarEntries() + content.5.asToolbarEntries()
      + content.6.asToolbarEntries()
  }
}

extension TupleView8: ToolbarEntryProvider
where
  C0: ToolbarEntryProvider, C1: ToolbarEntryProvider, C2: ToolbarEntryProvider,
  C3: ToolbarEntryProvider, C4: ToolbarEntryProvider, C5: ToolbarEntryProvider,
  C6: ToolbarEntryProvider, C7: ToolbarEntryProvider
{
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries() + content.2.asToolbarEntries()
      + content.3.asToolbarEntries() + content.4.asToolbarEntries() + content.5.asToolbarEntries()
      + content.6.asToolbarEntries() + content.7.asToolbarEntries()
  }
}

extension TupleView9: ToolbarEntryProvider
where
  C0: ToolbarEntryProvider, C1: ToolbarEntryProvider, C2: ToolbarEntryProvider,
  C3: ToolbarEntryProvider, C4: ToolbarEntryProvider, C5: ToolbarEntryProvider,
  C6: ToolbarEntryProvider, C7: ToolbarEntryProvider, C8: ToolbarEntryProvider
{
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries() + content.2.asToolbarEntries()
      + content.3.asToolbarEntries() + content.4.asToolbarEntries() + content.5.asToolbarEntries()
      + content.6.asToolbarEntries() + content.7.asToolbarEntries() + content.8.asToolbarEntries()
  }
}

extension TupleView10: ToolbarEntryProvider
where
  C0: ToolbarEntryProvider, C1: ToolbarEntryProvider, C2: ToolbarEntryProvider,
  C3: ToolbarEntryProvider, C4: ToolbarEntryProvider, C5: ToolbarEntryProvider,
  C6: ToolbarEntryProvider, C7: ToolbarEntryProvider, C8: ToolbarEntryProvider,
  C9: ToolbarEntryProvider
{
  fileprivate func asToolbarEntries() -> [ToolbarEntry] {
    content.0.asToolbarEntries() + content.1.asToolbarEntries() + content.2.asToolbarEntries()
      + content.3.asToolbarEntries() + content.4.asToolbarEntries() + content.5.asToolbarEntries()
      + content.6.asToolbarEntries() + content.7.asToolbarEntries() + content.8.asToolbarEntries()
      + content.9.asToolbarEntries()
  }
}
