import Foundation

struct Post: Codable, Identifiable, Sendable {
  let id: Int
  let title: String
  let body: String
}
