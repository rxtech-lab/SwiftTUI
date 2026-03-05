import Foundation

struct AnyNavigationDestination {
  let id = UUID()
  let buildView: () -> GenericView
}

typealias NavigationRouteHandler = (AnyNavigationDestination) -> Void

private struct NavigationRouteHandlerEnvironmentKey: EnvironmentKey {
  static var defaultValue: NavigationRouteHandler? { nil }
}

extension EnvironmentValues {
  var navigationRouteHandler: NavigationRouteHandler? {
    get { self[NavigationRouteHandlerEnvironmentKey.self] }
    set { self[NavigationRouteHandlerEnvironmentKey.self] = newValue }
  }
}

struct NavigationDestinationView: View, PrimitiveView {
  let destination: AnyNavigationDestination

  static var size: Int? { 1 }

  func buildNode(_ node: Node) {
    node.addNode(at: 0, Node(view: destination.buildView()))
    node.control = node.children[0].control(at: 0)
  }

  func updateNode(_ node: Node) {
    let previous = node.view as! NavigationDestinationView
    node.view = self

    if previous.destination.id == destination.id {
      node.children[0].update(using: destination.buildView())
      node.control = node.children[0].control(at: 0)
      return
    }

    node.removeNode(at: 0)
    node.addNode(at: 0, Node(view: destination.buildView()))
    node.control = node.children[0].control(at: 0)
  }
}
