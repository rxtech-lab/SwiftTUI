import Foundation

public struct NavigationLink<Label: View, Destination: View>: View {
  let label: Label
  let destination: Destination?
  let value: AnyHashable?

  @Environment(\.navigationRouteHandler) private var navigationRouteHandler: NavigationRouteHandler?
  @Environment(\.navigationPushValueHandler) private var navigationPushValueHandler:
    NavigationPushValueHandler?

  public init(destination: Destination, @ViewBuilder label: () -> Label) {
    self.label = label()
    self.destination = destination
    self.value = nil
  }

  public init(_ title: String, destination: Destination) where Label == Text {
    self.label = Text(title)
    self.destination = destination
    self.value = nil
  }

  public init<V: Hashable>(value: V, @ViewBuilder label: () -> Label) where Destination == Never {
    self.label = label()
    self.destination = nil
    self.value = AnyHashable(value)
  }

  public init<V: Hashable>(_ title: String, value: V) where Label == Text, Destination == Never {
    self.label = Text(title)
    self.destination = nil
    self.value = AnyHashable(value)
  }

  public var body: some View {
    Button(action: {
      if let value {
        navigationPushValueHandler?(value)
      } else if let destination {
        navigationRouteHandler?(AnyNavigationDestination(buildView: { destination.view }))
      }
    }) {
      label
    }
  }
}
