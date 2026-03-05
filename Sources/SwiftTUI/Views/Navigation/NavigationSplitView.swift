import Foundation

public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View {
  let sidebar: Sidebar
  let content: Content
  let detail: Detail

  @State private var detailDestination: AnyNavigationDestination?

  public init(
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder content: () -> Content,
    @ViewBuilder detail: () -> Detail
  ) {
    self.sidebar = sidebar()
    self.content = content()
    self.detail = detail()
  }

  public init(
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder detail: () -> Detail
  ) where Content == EmptyView {
    self.sidebar = sidebar()
    self.content = EmptyView()
    self.detail = detail()
  }

  @ViewBuilder
  private var resolvedDetail: some View {
    if let detailDestination {
      NavigationDestinationView(destination: detailDestination)
    } else {
      detail
    }
  }

  public var body: some View {
    ToolbarHost(
      content:
        HStack {
          sidebar
            .environment(
              \.navigationRouteHandler,
              { destination in
                detailDestination = destination
              })

          if !(content is EmptyView) {
            Divider()

            content
              .environment(
                \.navigationRouteHandler,
                { destination in
                  detailDestination = destination
                })
          }

          Divider()

          resolvedDetail
            .frame(minWidth: 0, maxWidth: .infinity)
        }
    )
  }
}
