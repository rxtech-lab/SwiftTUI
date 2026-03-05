import Foundation

extension View {
  public func tag<T: Hashable>(_ value: T) -> some View {
    Tag(content: self, value: value)
  }
}

private struct Tag<Content: View, Value: Hashable>: View, PrimitiveView, ModifierView {
  let content: Content
  let value: Value

  static var size: Int? { Content.size }

  func buildNode(_ node: Node) {
    node.controls = WeakSet<Control>()
    node.addNode(at: 0, Node(view: content.view))
  }

  func updateNode(_ node: Node) {
    node.view = self
    node.children[0].update(using: content.view)
    for control in node.controls?.values ?? [] {
      control.selectionTag = AnyHashable(value)
    }
  }

  func passControl(_ control: Control, node: Node) -> Control {
    control.selectionTag = AnyHashable(value)
    node.controls?.add(control)
    return control
  }
}
