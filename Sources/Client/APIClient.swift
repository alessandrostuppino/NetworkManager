import Foundation

/// A generic client for handling API requests with both Combine and async/await support.
public final class APIClient: @unchecked Sendable {
  
  // MARK: Lifecycle
  
  // MARK: - Initialization
  
  /// Initializes a new APIClient instance.
  /// - Parameters:
  ///   - qos: The quality of service for the API queue. Default is .background.
  ///   - logLevel: The initial log level for request/response logging. Default is .none.
  public init(
    configuration: URLSessionConfiguration? = nil,
    qos: DispatchQoS = .background,
    logLevel: LogLevel = .none,
    decoder: JSONDecoder? = nil,
    retryHandler: RetryHandler? = nil
  ) {
    self._logLevel = logLevel
    self.apiQueue = DispatchQueue(label: "com.apiQueue", qos: qos)
    self._decoder = decoder ?? JSONDecoder()
    self._retryHandler = retryHandler ?? DefaultRetryHandler(numberOfRetries: 0)
    self._configuration = configuration
    self._requestsToRetry = []
    self._activeSessions = Set()
  }
  
  // MARK: Private
  
  // MARK: - Properties
  
  /// Queue for handling API operations
  private let apiQueue: DispatchQueue
  
  /// Current log level for request/response logging
  private var _logLevel: LogLevel
  
  /// Thread-safe access to log level
  private var logLevel: LogLevel {
    get { return apiQueue.sync { _logLevel } }
    set { apiQueue.sync { _logLevel = newValue } }
  }
  
  private var _configuration: URLSessionConfiguration?
  
  /// Thread-safe access to configuration
  private var configuration: URLSessionConfiguration? {
    get { return apiQueue.sync { _configuration } }
    set { apiQueue.sync { _configuration = newValue } }
  }
  
  /// Retry handler for failed requests
  private var _retryHandler: RetryHandler?
  
  /// Thread-safe access to the retry handler
  private var retryHandler: RetryHandler {
    get { return apiQueue.sync { _retryHandler ?? DefaultRetryHandler(numberOfRetries: 0) } }
    set { apiQueue.sync { _retryHandler = newValue } }
  }
  
  /// Array to store requests that are to be retried
  private var _requestsToRetry: [URLRequest]
  
  /// Thread-safe access to requests to retry
  private var requestsToRetry: [URLRequest] {
    get { return apiQueue.sync { _requestsToRetry } }
    set { apiQueue.sync(flags: .barrier) { _requestsToRetry = newValue } }
  }
  
  /// Thread-safe method to append a request to retry
  private func appendRequestToRetry(_ request: URLRequest) {
    apiQueue.sync(flags: .barrier) {
      _requestsToRetry.append(request)
    }
  }
  
  /// Thread-safe method to clear requests to retry
  private func clearRequestsToRetry() {
    apiQueue.sync(flags: .barrier) {
      _requestsToRetry.removeAll()
    }
  }
  
  private var _decoder: JSONDecoder
  
  /// Thread-safe access to decoder
  private var decoder: JSONDecoder {
    get { return apiQueue.sync { _decoder } }
    set { apiQueue.sync { _decoder = newValue } }
  }
  
  private var _activeSessions: Set<URLSession>
  
  /// Thread-safe access to active sessions
  private var activeSessions: Set<URLSession> {
    get { return apiQueue.sync { _activeSessions } }
    set { apiQueue.sync(flags: .barrier) { _activeSessions = newValue } }
  }
  
  /// Thread-safe method to add a session
  private func addSession(_ session: URLSession) {
    apiQueue.async {
      self._activeSessions.insert(session)
    }
  }
  
  /// Thread-safe method to remove a session
  private func removeSession(_ session: URLSession) {
    apiQueue.async {
      self._activeSessions.remove(session)
    }
  }
}

extension APIClient {
  /// Performs a network request.
  /// - Parameter endpoint: The NetworkRouter defining the request.
  /// - Returns: The decoded response.
  /// - Throws: A NetworkError if the request fails.
  public func request<T: Codable>(_ endpoint: any NetworkRouter) async throws -> T{
    guard let urlRequest = try? endpoint.asURLRequest() else { throw NetworkError.unknown }
    
    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let self else {
        continuation.resume(throwing: NetworkError.unknown)
        return
      }
      apiQueue.async {
        Task {
          do {
            let result: T = try await self.makeAsyncRequest(urlRequest: urlRequest, retryCount: 3)
            continuation.resume(returning: result)
          } catch let error as NetworkError {
            continuation.resume(throwing: error)
          } catch {
            continuation.resume(throwing: NetworkError.unknown)
          }
        }
      }
    }
  }
  
  /// Internal method to make the actual async network request.
  private func makeAsyncRequest<T: Codable>(urlRequest: URLRequest, retryCount: Int) async throws -> T {
    URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
    
    let session = configuredSession(configuration: configuration)
    
    do {
      let (data, response) = try await session.data(for: urlRequest)
      
      guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.unknown }
      
      URLSessionLogger.shared.logResponse(response, data: data, error: nil, logLevel: logLevel)
      
      if 200..<300 ~= httpResponse.statusCode {
        do {
          // Use thread-safe decoder
          let decodedResponse = try self.decoder.decode(T.self, from: data)
          return decodedResponse
        } catch {
          throw mapErrorToNetworkError(error)
        }
      } else {
        let error = mapErrorResponseToCustomErrorData(data, statusCode: httpResponse.statusCode)
        throw error
      }
    } catch {
      return try await handleAsyncRetry(urlRequest: urlRequest, retryCount: retryCount, error: error)
    }
  }
  
  /// Handles retry logic for failed async requests.
  private func handleAsyncRetry<T: Codable>(urlRequest: URLRequest, retryCount: Int, error: Error) async throws -> T {
    let networkError = error as? NetworkError ?? mapErrorToNetworkError(error)
    
    return try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          let shouldRetry = await retryHandler.shouldRetryAsync(request: urlRequest, error: networkError)
          
          if retryCount > 0 && shouldRetry {
            // Use thread-safe method
            appendRequestToRetry(urlRequest)
            
            // Safely access last request
            let lastRequest = apiQueue.sync { _requestsToRetry.last ?? urlRequest }
            
            let newUrlRequest = try await retryHandler.modifyRequestForRetryAsync(
              client: self,
              request: lastRequest,
              error: networkError
            )
            
            // Use thread-safe method
            clearRequestsToRetry()
            
            do {
              let result: T = try await makeAsyncRequest(urlRequest: newUrlRequest, retryCount: retryCount - 1)
              continuation.resume(returning: result)
            } catch {
              continuation.resume(throwing: error)
            }
          } else {
            continuation.resume(throwing: networkError)
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}

extension APIClient {
  /// Performs a file upload request.
  /// - Parameters:
  ///   - endpoint: The NetworkRouter defining the request.
  ///   - withName: The name to be used for the file in the multipart form data.
  ///   - data: The file data to be uploaded.
  ///   - progressCompletion: A closure to handle upload progress updates.
  /// - Returns: The decoded response.
  /// - Throws: A NetworkError if the request fails.
  public func uploadRequest<T: Codable>(
    _ endpoint: any NetworkRouter,
    withName: String,
    data: Data?,
    progressCompletion: @escaping ProgressHandler
  ) async throws -> T {
    guard let urlRequest = try? endpoint.asURLRequest(), let data else { throw NetworkError.unknown }
    
    return try await withCheckedThrowingContinuation { [weak self] continuation in
      guard let self else {
        continuation.resume(throwing: NetworkError.unknown)
        return
      }
      apiQueue.async {
        Task {
          do {
            let result: T = try await self.makeAsyncUploadRequest(
              urlRequest: urlRequest, params: endpoint.params,
              withName: withName, data: data,
              progressCompletion: progressCompletion,
              retryCount: 3
            )
            continuation.resume(returning: result)
          } catch let error as NetworkError {
            continuation.resume(throwing: error)
          } catch {
            continuation.resume(throwing: NetworkError.unknown)
          }
        }
      }
    }
  }
  
  /// Internal method to make the actual async upload request.
  private func makeAsyncUploadRequest<T: Codable>(
    urlRequest: URLRequest,
    params: Codable?,
    withName: String,
    data: Data,
    progressCompletion: @escaping ProgressHandler,
    retryCount: Int
  ) async throws -> T {
    URLSessionLogger.shared.logRequest(urlRequest, logLevel: logLevel)
    let (newUrlRequest, bodyData) = createBody(urlRequest: urlRequest, parameters: params, data: data, filename: withName)
    
    let progressDelegate = UploadProgressDelegate()
    progressDelegate.progressHandler = progressCompletion
    let session = configuredSession(delegate: progressDelegate, configuration: configuration)
    
    do {
      let (data, response) = try await session.upload(for: newUrlRequest, from: bodyData)
      
      guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.unknown }
      
      URLSessionLogger.shared.logResponse(response, data: data, error: nil, logLevel: logLevel)
      
      if 200..<300 ~= httpResponse.statusCode {
        do {
          return try self.decoder.decode(T.self, from: data)
        } catch {
          throw mapErrorToNetworkError(error)
        }
      } else {
        throw mapErrorResponseToCustomErrorData(data, statusCode: httpResponse.statusCode)
      }
    } catch {
      return try await handleAsyncRetry(urlRequest: urlRequest, retryCount: retryCount, error: error)
    }
  }
}

// MARK: - APIClient+ErrorHandling

extension APIClient {
  // MARK: - Error Handling
  
  /// Maps a general Error to a NetworkError.
  private func mapErrorToNetworkError(_ error: Error) -> NetworkError {
    if let networkError = error as? NetworkError {
      return networkError
    }
    return switch error {
      case let urlError as URLError: .urlError(urlError)
      case let decodingError as DecodingError: .decodingError(decodingError)
      default: .responseError(error)
    }
  }
  
  /// Maps an error response to a NetworkError.
  private func mapErrorResponseToCustomErrorData(_ data: Data, statusCode: Int) -> NetworkError {
    .customError(statusCode, data)
  }
}

// MARK: - APIClient+AsyncStreamRequest

extension APIClient {
  /// Performs a streaming network request.
  /// - Parameter endpoint: The NetworkRouter defining the request.
  /// - Returns: An AsyncThrowingStream that yields decoded responses as they arrive.
  @available(iOS 15.0, *)
  public func asyncStreamRequest<T: Codable>(_ endpoint: any NetworkRouter) -> AsyncThrowingStream<T, Error> {
    guard let urlRequest = try? endpoint.asURLRequest() else {
      return AsyncThrowingStream { continuation in
        continuation.finish(throwing: NetworkError.unknown)
      }
    }
    
    return makeAsyncStreamRequest(urlRequest: urlRequest)
  }
  
  /// Internal method to make the actual async streaming network request.
  @available(iOS 15.0, *)
  private func makeAsyncStreamRequest<T: Codable>(urlRequest: URLRequest) -> AsyncThrowingStream<T, Error> {
    return AsyncThrowingStream { [weak self] continuation in
      guard let self else {
        continuation.finish(throwing: NetworkError.unknown)
        return
      }
      
      let session = self.configuredSession(configuration: self.configuration)
      
      let task = Task {
        do {
          let (bytes, response) = try await session.bytes(for: urlRequest)
          URLSessionLogger.shared.logResponse(response, data: nil, error: nil, logLevel: self.logLevel)
          
          var iterator = bytes.makeAsyncIterator()
          var dataBuffer = Data()
          
          while let chunk = try await iterator.next() {
            dataBuffer.append(chunk)
            
            while let range = dataBuffer.range(of: Data("\n".utf8)) {
              let lineData = dataBuffer.subdata(in: dataBuffer.startIndex..<range.lowerBound)
              dataBuffer.removeSubrange(dataBuffer.startIndex..<range.upperBound)
              
              do {
                let decoder = JSONDecoder()
                let decodedObject = try decoder.decode(T.self, from: lineData)
                continuation.yield(decodedObject)
              } catch {
                continuation.finish(throwing: error)
                return
              }
            }
          }
          
          if !dataBuffer.isEmpty {
            do {
              let decoder = JSONDecoder()
              let decodedObject = try decoder.decode(T.self, from: dataBuffer)
              continuation.yield(decodedObject)
            } catch {
              continuation.finish(throwing: error)
              return
            }
          }
          
          continuation.finish()
        } catch {
          URLSessionLogger.shared.logResponse(nil, data: nil, error: error, logLevel: self.logLevel)
          continuation.finish(throwing: error)
        }
      }
      
      continuation.onTermination = { @Sendable _ in
        task.cancel()
      }
    }
  }
}

extension APIClient {
  // MARK: - Helper Methods
  
  /// Configures and returns a URLSession.
  private func configuredSession(delegate: URLSessionDelegate? = nil, configuration: URLSessionConfiguration? = nil) -> URLSession {
    guard let configuration else {
      let configuration = URLSessionConfiguration.default
      configuration.timeoutIntervalForRequest = 120
      configuration.timeoutIntervalForResource = 120
      configuration.requestCachePolicy =
        .reloadIgnoringLocalAndRemoteCacheData
      return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    addSession(session)
    return session
  }
  
  /// Creates the body for a multipart form data request.
  private func createBody(urlRequest: URLRequest, parameters: Codable?, data: Data, filename: String) -> (URLRequest, Data) {
    var newUrlRequest = urlRequest
    let boundary = "Boundary-\(UUID().uuidString)"
    let mime = MimeTypeDetector.detectMimeType(from: data)
    newUrlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    
    var body = Data()
    
    if let parameters {
      do {
        let jsonData = try JSONEncoder().encode(parameters)
        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
          for (key, value) in jsonObject {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
          }
        }
      } catch {
        print("Error encoding parameters: \(error)")
      }
    }
    
    body.appendString("--\(boundary)\r\n")
    body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename).\(mime?.ext ?? "")\"\r\n")
    body.appendString("Content-Type: \(mime?.mime ?? "")\r\n\r\n")
    body.append(data)
    body.appendString("\r\n")
    body.appendString("--\(boundary)--\r\n")
    
    return (newUrlRequest, body)
  }
}

// MARK: - Session Management

extension APIClient {
  private func trackSession(_ session: URLSession) {
    addSession(session)
  }
  
  /// Cancels all ongoing network requests
  func cancelAllRequests() {
    let sessionsToCancel = activeSessions
    apiQueue.sync(flags: .barrier) {
      sessionsToCancel.forEach { session in
        session.invalidateAndCancel()
      }
      _activeSessions.removeAll()
      _requestsToRetry.removeAll()
    }
  }
}
