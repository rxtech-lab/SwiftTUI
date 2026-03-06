import SwiftTUI

struct PostDetailView: View {
  let post: Post

  @State private var comments: [Comment] = []
  @State private var isLoading = true

  var body: some View {
    VStack(alignment: .leading) {
      Text(post.title).bold()
      Text("")
      Text(post.body)
      Divider()
      if isLoading {
        Text("Loading comments...")
      } else {
        Text("Comments (\(comments.count))").bold()
        List {
          ForEach(comments) { comment in
            NavigationLink(value: comment) {
              VStack(alignment: .leading) {
                Text(comment.name).bold()
                Text(comment.email).foregroundColor(.cyan)
              }
            }
          }
        }
      }
    }
    .task {
      do {
        let fetched = try await APIClient.fetchComments(postId: post.id)
        await MainActor.run {
          comments = fetched
          isLoading = false
        }
      } catch {
        await MainActor.run {
          comments = []
          isLoading = false
        }
      }
    }
  }
}
