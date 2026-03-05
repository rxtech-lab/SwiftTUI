import Foundation

public struct NavigationLink<Label: View, Destination: View>: View {
  let label: Label
  let destination: Destination

  @Environment(\.navigationRouteHandler) private var navigationRouteHandler: NavigationRouteHandler?

  public init(destination: Destination, @ViewBuilder label: () -> Label) {
    self.label = label()
    self.destination = destination
  }

  public init(_ title: String, destination: Destination) where Label == Text {
    self.label = Text(title)
    self.destination = destination
  }

  public var body: some View {
    Button(action: {
      navigationRouteHandler?(AnyNavigationDestination(buildView: { destination.view }))
    }) {
      label
    }
  }
}
