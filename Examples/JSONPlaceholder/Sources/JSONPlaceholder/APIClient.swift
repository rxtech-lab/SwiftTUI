import Foundation

enum APIClient {
  static let baseURL = "https://jsonplaceholder.typicode.com"

  static func fetchPosts() async throws -> [Post] {
    let url = URL(string: "\(baseURL)/posts")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([Post].self, from: data)
  }

  static func fetchComments(postId: Int) async throws -> [Comment] {
    let url = URL(string: "\(baseURL)/posts/\(postId)/comments")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode([Comment].self, from: data)
  }
}
