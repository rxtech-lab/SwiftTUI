import Foundation

extension View {
  public func onAppear(_ action: @escaping () -> Void) -> some View {
    return OnAppear(content: self, action: action)
  }
}

private struct OnAppear<Content: View>: View, PrimitiveView, ModifierView {
  let content: Content
  let action: () -> Void

  static var size: Int? { Content.size }

  func buildNode(_ node: Node) {
    node.controls = WeakSet<Control>()
    node.addNode(at: 0, Node(view: content.view))
  }

  func updateNode(_ node: Node) {
    node.view = self
    node.children[0].update(using: content.view)
    for control in node.controls?.values ?? [] {
      (control as! OnAppearControl).action = action
    }
  }

  func passControl(_ control: Control, node: Node) -> Control {
    if let onAppearControl = control.parent { return onAppearControl }
    let onAppearControl = OnAppearControl(action: action)
    onAppearControl.addSubview(control, at: 0)
    node.controls?.add(onAppearControl)
    return onAppearControl
  }

  private class OnAppearControl: Control {
    var action: () -> Void
    var didAppear = false

    init(action: @escaping () -> Void) {
      self.action = action
    }

    override func size(proposedSize: Size) -> Size {
      children[0].size(proposedSize: proposedSize)
    }

    override func layout(size: Size) {
      super.layout(size: size)
      children[0].layout(size: size)
      if !didAppear {
        didAppear = true
        action()
      }
    }
  }
}
