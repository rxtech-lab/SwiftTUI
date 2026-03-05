import Foundation

struct Post: Codable, Identifiable, Sendable {
  let id: Int
  let userId: Int
  let title: String
  let body: String
}

struct Comment: Codable, Identifiable, Sendable {
  let id: Int
  let postId: Int
  let name: String
  let email: String
  let body: String
}
