import Foundation

public struct NavigationStack<Content: View>: View {
  let content: Content

  @State private var stack: [AnyNavigationDestination] = []

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  @ViewBuilder
  private var activeContent: some View {
    if let destination = stack.last {
      NavigationDestinationView(destination: destination)
    } else {
      content
    }
  }

  public var body: some View {
    ToolbarHost(
      content: activeContent,
      showBackButton: !stack.isEmpty,
      onBack: {
        pop()
      }
    )
    .environment(
      \.navigationRouteHandler,
      { destination in
        stack.append(destination)
      })
  }

  private func pop() -> Bool {
    guard !stack.isEmpty else { return false }
    stack.removeLast()
    return true
  }
}
