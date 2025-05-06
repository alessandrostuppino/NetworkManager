import Foundation

/// A basic implementation of RetryHandler that uses all default behaviors
public struct DefaultRetryHandler: RetryHandler {
  // MARK: Lifecycle
  
  public init(numberOfRetries: Int) {
    self.numberOfRetries = numberOfRetries
  }
  
  // MARK: Public
  
  public let numberOfRetries: Int
}
