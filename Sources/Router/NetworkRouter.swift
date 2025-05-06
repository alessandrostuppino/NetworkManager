import Foundation

// MARK: - RequestMethod

public enum RequestMethod: String, Sendable {
  case get, post, put, patch, trace, delete, head
}

// MARK: - NetworkRouterError

public enum NetworkRouterError: Error, Sendable {
  case invalidURL, encodingFailed, missingHTTPMethod
}

// MARK: - EmptyParameters

public struct EmptyParameters: Codable {}

// MARK: - NetworkRouter

public protocol NetworkRouter: Sendable {
  associatedtype Parameters: Codable = EmptyParameters
  associatedtype QueryParameters: Codable = EmptyParameters
  
  var baseURLString: String { get }
  var method: RequestMethod? { get }
  var path: String { get }
  var headers: [String: String]? { get }
  var params: Parameters? { get }
  var queryParams: QueryParameters? { get }
  var version: APIVersion? { get }
  func asURLRequest() throws -> URLRequest
}

// MARK: - Network Router Protocol Default Implementation

extension NetworkRouter {
  public var baseURLString: String { "" }
  
  public var method: RequestMethod? { .none }
  
  public var path: String { "" }
  
  public var headers: [String: String]? { nil }
  
  public var params: Parameters? { nil }
  
  public var queryParams: QueryParameters? { nil }
  
  public var version: APIVersion? { nil }
  
  // MARK: URLRequestConvertible
  
  public func asURLRequest() throws -> URLRequest {
    let fullPath = baseURLString + (version?.path ?? "") + path
    guard let url = URL(string: fullPath) else { throw NetworkRouterError.invalidURL }
    guard let method else { throw NetworkRouterError.missingHTTPMethod }
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = method.rawValue.uppercased()
    urlRequest.allHTTPHeaderFields = headers
    
    if let queryParams {
      try URLEncoding(destination: .queryString).encode(&urlRequest, with: queryParams)
    }
    
    // Determine the encoding based on the HTTP method and headers
    switch method {
      case .post, .put, .patch:
        if let contentType = headers?[ContentTypeHeaders.name], contentType.contains("application/x-www-form-urlencoded") {
          if let params {
            try URLEncoding(destination: .httpBody).encode(&urlRequest, with: params)
          }
        } else {
          if let params {
            try JSONEncoding().encode(&urlRequest, with: params)
          }
        }
      default:
        break
    }
    
    return urlRequest
  }
}
