import Foundation

extension View {
  public func navigationDestination<D: Hashable, C: View>(
    for data: D.Type,
    @ViewBuilder destination: @escaping (D) -> C
  ) -> some View {
    NavigationDestinationModifier(content: self, dataType: data, destination: destination)
  }
}

private struct NavigationDestinationModifier<Content: View, D: Hashable, Destination: View>: View,
  PrimitiveView
{
  let content: Content
  let dataType: D.Type
  let destination: (D) -> Destination

  static var size: Int? { Content.size }

  func buildNode(_ node: Node) {
    node.addNode(at: 0, Node(view: content.view))
    registerDestination(node: node)
  }

  func updateNode(_ node: Node) {
    node.view = self
    node.children[0].update(using: content.view)
    registerDestination(node: node)
  }

  private func registerDestination(node: Node) {
    let env = node.resolveEnvironment()
    env.navigationDestinationRegistry?.register(for: dataType) { value in
      destination(value).view
    }
  }
}
