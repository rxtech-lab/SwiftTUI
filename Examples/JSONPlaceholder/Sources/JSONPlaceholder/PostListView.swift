import SwiftTUI

struct PostListView: View {
  @State private var posts: [Post] = []
  @State private var isLoading = true

  var body: some View {
    VStack {
      Text("JSONPlaceholder Posts").bold()
      Divider()
      if isLoading {
        Text("Loading posts...")
      } else {
        List {
          ForEach(posts) { post in
            NavigationLink(destination: PostDetailView(post: post)) {
              Text("\(post.id). \(post.title)")
            }
          }
        }
      }
    }
    .task {
      do {
        let fetched = try await APIClient.fetchPosts()
        await MainActor.run {
          posts = fetched
          isLoading = false
        }
      } catch {
        await MainActor.run {
          posts = []
          isLoading = false
        }
      }
    }
  }
}
