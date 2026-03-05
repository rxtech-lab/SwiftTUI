import Foundation

public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View {
  let sidebar: Sidebar
  let content: Content
  let detail: Detail
  let pathBinding: Binding<NavigationPath>?

  @State private var detailDestination: AnyNavigationDestination?
  @State private var internalPath = NavigationPath()

  public init(
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder content: () -> Content,
    @ViewBuilder detail: () -> Detail
  ) {
    self.sidebar = sidebar()
    self.content = content()
    self.detail = detail()
    self.pathBinding = nil
  }

  public init(
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder detail: () -> Detail
  ) where Content == EmptyView {
    self.sidebar = sidebar()
    self.content = EmptyView()
    self.detail = detail()
    self.pathBinding = nil
  }

  public init(
    path: Binding<NavigationPath>,
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder content: () -> Content,
    @ViewBuilder detail: () -> Detail
  ) {
    self.sidebar = sidebar()
    self.content = content()
    self.detail = detail()
    self.pathBinding = path
  }

  public init(
    path: Binding<NavigationPath>,
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder detail: () -> Detail
  ) where Content == EmptyView {
    self.sidebar = sidebar()
    self.content = EmptyView()
    self.detail = detail()
    self.pathBinding = path
  }

  private var currentPath: NavigationPath {
    pathBinding?.wrappedValue ?? internalPath
  }

  @ViewBuilder
  private var resolvedDetail: some View {
    if let detailDestination {
      NavigationDestinationView(destination: detailDestination)
    } else if let lastValue = currentPath.elements.last {
      NavigationValueDestinationView(value: lastValue)
    } else {
      detail
    }
  }

  private func pushValue(_ value: AnyHashable) {
    if pathBinding != nil {
      pathBinding!.wrappedValue.append(value)
    } else {
      internalPath.append(value)
    }
  }

  public var body: some View {
    NavigationRegistryHost(
      content:
        ToolbarHost(
          content:
            HStack {
              sidebar
                .environment(
                  \.navigationRouteHandler,
                  { destination in
                    detailDestination = destination
                  }
                )
                .environment(
                  \.navigationPushValueHandler,
                  { value in
                    detailDestination = nil
                    pushValue(value)
                  })

              if !(content is EmptyView) {
                Divider()

                content
                  .environment(
                    \.navigationRouteHandler,
                    { destination in
                      detailDestination = destination
                    }
                  )
                  .environment(
                    \.navigationPushValueHandler,
                    { value in
                      detailDestination = nil
                      pushValue(value)
                    })
              }

              Divider()

              resolvedDetail
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        )
    )
  }
}
