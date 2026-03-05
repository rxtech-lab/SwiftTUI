import Foundation

struct AnyNavigationDestination {
  let id = UUID()
  let buildView: () -> GenericView
}

typealias NavigationRouteHandler = (AnyNavigationDestination) -> Void
typealias NavigationPushValueHandler = (AnyHashable) -> Void

private struct NavigationRouteHandlerEnvironmentKey: EnvironmentKey {
  static var defaultValue: NavigationRouteHandler? { nil }
}

private struct NavigationPushValueHandlerEnvironmentKey: EnvironmentKey {
  static var defaultValue: NavigationPushValueHandler? { nil }
}

extension EnvironmentValues {
  var navigationRouteHandler: NavigationRouteHandler? {
    get { self[NavigationRouteHandlerEnvironmentKey.self] }
    set { self[NavigationRouteHandlerEnvironmentKey.self] = newValue }
  }

  var navigationPushValueHandler: NavigationPushValueHandler? {
    get { self[NavigationPushValueHandlerEnvironmentKey.self] }
    set { self[NavigationPushValueHandlerEnvironmentKey.self] = newValue }
  }
}

// MARK: - Destination Registry

class NavigationDestinationRegistry {
  private var builders: [ObjectIdentifier: (AnyHashable) -> GenericView] = [:]

  func register<T: Hashable>(for type: T.Type, builder: @escaping (T) -> GenericView) {
    builders[ObjectIdentifier(type)] = { value in
      builder(value as! T)
    }
  }

  func build(for value: AnyHashable) -> GenericView? {
    let typeId = ObjectIdentifier(type(of: value.base))
    return builders[typeId]?(value)
  }
}

private struct NavigationDestinationRegistryEnvironmentKey: EnvironmentKey {
  static var defaultValue: NavigationDestinationRegistry? { nil }
}

extension EnvironmentValues {
  var navigationDestinationRegistry: NavigationDestinationRegistry? {
    get { self[NavigationDestinationRegistryEnvironmentKey.self] }
    set { self[NavigationDestinationRegistryEnvironmentKey.self] = newValue }
  }
}

// MARK: - Registry Host

struct NavigationRegistryHost<Content: View>: View, PrimitiveView {
  let content: Content

  static var size: Int? { Content.size }

  private static var stateKey: String { "_navRegistry" }

  func buildNode(_ node: Node) {
    let registry = NavigationDestinationRegistry()
    node.state[Self.stateKey] = registry
    node.environment = { $0.navigationDestinationRegistry = registry }
    node.addNode(at: 0, Node(view: content.view))
  }

  func updateNode(_ node: Node) {
    let registry = node.state[Self.stateKey] as! NavigationDestinationRegistry
    node.view = self
    node.environment = { $0.navigationDestinationRegistry = registry }
    node.children[0].update(using: content.view)
  }
}

// MARK: - Value-based Destination View

struct NavigationValueDestinationView: View, PrimitiveView {
  let value: AnyHashable

  static var size: Int? { 1 }

  func buildNode(_ node: Node) {
    let env = node.resolveEnvironment()
    let view = env.navigationDestinationRegistry?.build(for: value) ?? Text("No destination").view
    node.addNode(at: 0, Node(view: view))
    node.control = node.children[0].control(at: 0)
  }

  func updateNode(_ node: Node) {
    let previous = node.view as! NavigationValueDestinationView
    node.view = self

    if previous.value == value {
      let env = node.resolveEnvironment()
      let view = env.navigationDestinationRegistry?.build(for: value) ?? Text("No destination").view
      node.children[0].update(using: view)
      node.control = node.children[0].control(at: 0)
      return
    }

    node.removeNode(at: 0)
    let env = node.resolveEnvironment()
    let view = env.navigationDestinationRegistry?.build(for: value) ?? Text("No destination").view
    node.addNode(at: 0, Node(view: view))
    node.control = node.children[0].control(at: 0)
  }
}

// MARK: - Navigation Destination View

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
