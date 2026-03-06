import Foundation

extension View {
  public func focusable(_ isFocusable: Bool = true) -> some View {
    Focusable(content: self, prefersDefaultFocus: isFocusable)
  }
}

private struct Focusable<Content: View>: View, PrimitiveView, ModifierView {
  let content: Content
  let prefersDefaultFocus: Bool

  static var size: Int? { Content.size }

  func buildNode(_ node: Node) {
    node.controls = WeakSet<Control>()
    node.addNode(at: 0, Node(view: content.view))
  }

  func updateNode(_ node: Node) {
    node.view = self
    node.children[0].update(using: content.view)
    for control in node.controls?.values ?? [] {
      control.prefersDefaultFocus = prefersDefaultFocus
    }
  }

  func passControl(_ control: Control, node: Node) -> Control {
    control.prefersDefaultFocus = prefersDefaultFocus
    node.controls?.add(control)
    return control
  }
}
