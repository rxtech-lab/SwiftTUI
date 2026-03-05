import Foundation

public struct NavigationStack<Content: View>: View {
  let content: Content
  let pathBinding: Binding<NavigationPath>?

  @State private var internalPath = NavigationPath()
  @State private var inlineStack: [AnyNavigationDestination] = []

  public init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
    self.pathBinding = nil
  }

  public init(path: Binding<NavigationPath>, @ViewBuilder _ content: () -> Content) {
    self.content = content()
    self.pathBinding = path
  }

  private var currentPath: NavigationPath {
    pathBinding?.wrappedValue ?? internalPath
  }

  private var hasDestination: Bool {
    !inlineStack.isEmpty || !currentPath.isEmpty
  }

  @ViewBuilder
  private var activeContent: some View {
    if let destination = inlineStack.last {
      NavigationDestinationView(destination: destination)
    } else if let lastValue = currentPath.elements.last {
      NavigationValueDestinationView(value: lastValue)
    } else {
      content
    }
  }

  public var body: some View {
    NavigationRegistryHost(
      content:
        ToolbarHost(
          content: activeContent,
          showBackButton: hasDestination,
          onBack: {
            pop()
          }
        )
        .environment(
          \.navigationRouteHandler,
          { destination in
            inlineStack.append(destination)
          }
        )
        .environment(
          \.navigationPushValueHandler,
          { value in
            pushValue(value)
          })
    )
  }

  private func pushValue(_ value: AnyHashable) {
    if pathBinding != nil {
      pathBinding!.wrappedValue.append(value)
    } else {
      internalPath.append(value)
    }
  }

  private func pop() -> Bool {
    if !inlineStack.isEmpty {
      inlineStack.removeLast()
      return true
    }
    if pathBinding != nil {
      guard !pathBinding!.wrappedValue.isEmpty else { return false }
      pathBinding!.wrappedValue.removeLast()
      return true
    }
    guard !internalPath.isEmpty else { return false }
    internalPath.removeLast()
    return true
  }
}
