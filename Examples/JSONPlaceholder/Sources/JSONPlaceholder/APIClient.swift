import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

enum APIClient {
  static let baseURL = "https://jsonplaceholder.typicode.com"

  static func fetchPosts() async throws -> [Post] {
    let url = URL(string: "\(baseURL)/posts")!
    let data = try await fetchData(from: url)
    return try JSONDecoder().decode([Post].self, from: data)
  }

  static func fetchComments(postId: Int) async throws -> [Comment] {
    let url = URL(string: "\(baseURL)/posts/\(postId)/comments")!
    let data = try await fetchData(from: url)
    return try JSONDecoder().decode([Comment].self, from: data)
  }

  private static func fetchData(from url: URL) async throws -> Data {
    #if canImport(FoundationNetworking)
      return try await withCheckedThrowingContinuation { continuation in
        URLSession.shared.dataTask(with: url) { data, _, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let data = data {
            continuation.resume(returning: data)
          } else {
            continuation.resume(throwing: URLError(.unknown))
          }
        }.resume()
      }
    #else
      let (data, _) = try await URLSession.shared.data(from: url)
      return data
    #endif
  }
}
