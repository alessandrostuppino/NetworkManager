import Foundation
import NetworkManager

struct PostsAPI: NetworkRouter, Sendable {
  var baseURLString: String { "https://jsonplaceholder.typicode.com/" }
  var method: RequestMethod? { .get }
  var path: String { "posts" }
  var headers: [String: String]? { nil }
  var params: Parameters? { nil }
  var queryParams: QueryParameters? { nil }
}
