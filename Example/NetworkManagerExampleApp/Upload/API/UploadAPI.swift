import Foundation
import NetworkManager

struct UploadAPI: Sendable, NetworkRouter {
  var baseURLString: String { "https://file.io/" }
  var method: RequestMethod? { .post }
  var headers: [String: String]? {
    HeaderHandler.shared.addAcceptHeaders(type: .applicationJson)
      .addContentTypeHeader(type: .formData)
      .build()
  }
}
