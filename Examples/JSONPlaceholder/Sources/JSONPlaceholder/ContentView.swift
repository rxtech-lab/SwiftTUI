import SwiftTUI

struct ContentView: View {
  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      PostListView()
        .navigationDestination(for: Post.self) { post in
          PostDetailView(post: post)
        }
        .navigationDestination(for: Comment.self) { comment in
          CommentDetailView(comment: comment)
        }
    }
    .toolbar {
      ToolbarItem(placement: .status) {
        Text("JSONPlaceholder")
      }
    }
  }
}
