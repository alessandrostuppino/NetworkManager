import Foundation

struct UploadResponse: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case success, status, id, key, path, nodeType, name, title, description, size, link
    case uploadResponsePrivate = "private"
    case expires, downloads, maxDownloads, autoDelete
    case planID = "planId"
    case screeningStatus, mimeType, created, modified
  }
  
  var success: Bool?
  var status: Int?
  var id, key, path, nodeType: String?
  var name, title, description: String?
  var size: Int?
  var link: String?
  var uploadResponsePrivate: Bool?
  var expires: String?
  var downloads, maxDownloads: Int?
  var autoDelete: Bool?
  var planID: Int?
  var screeningStatus, mimeType, created, modified: String?
}
