import Foundation

struct Post: Codable, Identifiable, Hashable, Sendable {
  let id: Int
  let userId: Int
  let title: String
  let body: String
}

struct Comment: Codable, Identifiable, Hashable, Sendable {
  let id: Int
  let postId: Int
  let name: String
  let email: String
  let body: String
}
