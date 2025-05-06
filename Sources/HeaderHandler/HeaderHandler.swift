import Foundation

// MARK: - ConnectionHeaders

public enum ConnectionHeaders: Sendable {
  case keepAlive
  case close
  case custom(String)
  
  public var value: String {
    switch self {
      case .keepAlive: "keep-alive"
      case .close: "close"
      case let .custom(customValue): customValue
    }
  }
  
  public static var name: String {
    return "connection"
  }
}

// MARK: - AcceptHeaders

public enum AcceptHeaders: Sendable {
  case all
  case applicationJson
  case applicationJsonUTF8
  case text
  case combinedAll
  case custom(String)
  
  public var value: String {
    switch self {
      case .all: "*/*"
      case .applicationJson: "application/json"
      case .applicationJsonUTF8: "application/json; charset=utf-8"
      case .text: "text/plain"
      case .combinedAll: "application/json, text/plain, */*"
      case let .custom(customValue): customValue
    }
  }
  
  public static var name: String { "accept" }
}

// MARK: - ContentTypeHeaders

public enum ContentTypeHeaders: Sendable {
  case applicationJson
  case applicationJsonUTF8
  case urlEncoded
  case formData
  case custom(String)
  
  public var value: String {
    switch self {
      case .applicationJson: "application/json"
      case .applicationJsonUTF8: "application/json; charset=utf-8"
      case .urlEncoded: "application/x-www-form-urlencoded"
      case .formData: "multipart/form-data"
      case let .custom(customValue): customValue
    }
  }
  
  public static var name: String { "content-type" }
}

// MARK: - AcceptEncodingHeaders

public enum AcceptEncodingHeaders: Sendable {
  case gzip
  case compress
  case deflate
  case br
  case identity
  case all
  case custom(String)
  
  public var value: String {
    switch self {
      case .gzip: "gzip"
      case .compress: "compress"
      case .deflate: "deflate"
      case .br: "br"
      case .identity: "identity"
      case .all: "*"
      case let .custom(customValue): customValue
    }
  }
  
  public static var name: String { "accept-encoding" }
}

// MARK: - AcceptLanguageHeaders

public enum AcceptLanguageHeaders: Sendable {
  case en
  case fa
  case all
  case custom(String)
  
  public var value: String {
    switch self {
      case .en: "en"
      case .fa: "fa"
      case .all: "*"
      case let .custom(customValue): customValue
    }
  }
  
  public static var name: String { "accept-language" }
}

// MARK: - AuthorizationType

public enum AuthorizationType: Sendable {
  case bearer(token: String)
  case basic(username: String, password: String)
  case custom(String)
  
  public var value: String {
    switch self {
      case .bearer(let token):
        return "Bearer \(token)"
      case .basic(let username, let password):
        let credentials = "\(username):\(password)"
        guard let encodedCredentials = credentials.data(using: .utf8)?.base64EncodedString() else {
          return ""
        }
        return "Basic \(encodedCredentials)"
      case let .custom(customValue):
        return customValue
    }
  }
  
  public static var name: String { "authorization" }
}

// MARK: - HeaderHandler

public class HeaderHandler: @unchecked Sendable {
  // MARK: Lifecycle
  
  private init() { _headers = [:] }
  
  // MARK: Internal
  
  public static let shared = HeaderHandler()
  
  private let queue = DispatchQueue(label: "com.headerHandler.queue")
  
  @discardableResult
  public func addContentTypeHeader(type: ContentTypeHeaders) -> HeaderHandler {
    queue.sync {
      _headers.updateValue(type.value, forKey: ContentTypeHeaders.name)
      return self
    }
    
  }
  
  @discardableResult
  public func addConnectionHeader(type: ConnectionHeaders) -> HeaderHandler {
    queue.sync {
      _headers.updateValue(type.value, forKey: ConnectionHeaders.name)
      return self
    }
    
  }
  
  @discardableResult
  public func addAcceptHeaders(type: AcceptHeaders) -> HeaderHandler {
    queue.sync {
      _headers.updateValue(type.value, forKey: AcceptHeaders.name)
      return self
    }
    
  }
  
  @discardableResult
  public func addAcceptLanguageHeaders(type: AcceptLanguageHeaders) -> HeaderHandler {
    queue.sync {
      _headers.updateValue(type.value, forKey: AcceptLanguageHeaders.name)
      return self
    }
    
  }
  
  @discardableResult
  public func addAcceptEncodingHeaders(type: AcceptEncodingHeaders) -> HeaderHandler {
    queue.sync {
      _headers.updateValue(type.value, forKey: AcceptEncodingHeaders.name)
      return self
    }
    
  }
  
  @discardableResult
  public func addAuthorizationHeader(type: AuthorizationType) -> HeaderHandler {
    queue.sync {
      _headers.updateValue(type.value, forKey: AuthorizationType.name)
      return self
    }
    
  }
  
  @discardableResult
  public func addCustomHeader(name: String, value: String) -> HeaderHandler {
    queue.sync {
      _headers.updateValue(value, forKey: name)
      return self
    }
    
  }
  
  public func build() -> [String: String] {
    return headers
  }
  
  // MARK: Private
  
  private var _headers: [String: String] = [:]
  private var headers: [String: String] {
    get { queue.sync { _headers } }
    set { queue.sync { _headers = newValue }}
  }
}
