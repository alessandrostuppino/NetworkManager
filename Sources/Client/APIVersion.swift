public enum APIVersion: Sendable {
  case v1
  case v2
  case custom(version: String)
  
  // MARK: Public
  
  public var path: String { "api/\(rawValue)/" }
  
  // MARK: Internal
  
  var rawValue: String {
    switch self {
      case .v1: "v1"
      case .v2: "v2"
      case let .custom(version): version
    }
  }
}
