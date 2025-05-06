import Foundation

/// A protocol defining the retry handling behavior for network requests.
public protocol RetryHandler: Sendable {
  /// The maximum number of retry attempts.
  var numberOfRetries: Int { get }
}

// MARK: - Default Implementations

public extension RetryHandler {
  /// Default implementation to determine if a retry should be attempted
  func shouldRetry(request: URLRequest, error: NetworkError) -> Bool {
    numberOfRetries > 0
  }
  
  /// Default implementation to modify request for retry
  func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?) {
    (request, nil)
  }
  
  /// Default async implementation to determine if a retry should be attempted
  func shouldRetryAsync(request: URLRequest, error: NetworkError) async -> Bool {
    numberOfRetries > 0
  }
  
  /// Default async implementation to modify request for retry
  func modifyRequestForRetryAsync(client: APIClient, request: URLRequest, error: NetworkError) async throws -> URLRequest {
    request
  }
}
