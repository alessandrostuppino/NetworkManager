# NetworkManager 🚀

**NetworkManager** is a **powerful** and **flexible networking layer** for Swift applications. It provides a **generic, protocol-oriented** approach to handling API requests based on **async/await** paradigm. This package is designed to be **easy to use**, **highly customizable**, and **fully compatible** with **Swift 6** and the **Sendable protocol**.

---

![Platform](https://img.shields.io/badge/platform-iOS%20|%20watchOS|%20tvOS%20|%20macOS-blue)
![Swift](https://img.shields.io/badge/swift-6.0-orange)

## 🎯 **Features**

- 🔗 **Generic API Client** for various types of network requests  
- 🧩 **Protocol-Oriented Design** for easy customization and extensibility   
- 🛡️ **Robust Error Handling** with custom error types  
- 🔄 **Retry Mechanism** for failed requests  
- 📤 **File Upload Support** with progress tracking  
- 🔧 **Flexible Parameter Encoding** (URL & JSON)  
- 🧾 **Comprehensive Logging System**  
- 📦 **MIME Type Detection** for file uploads  
- 🔒 **Thread-Safe Design** with Sendable protocol support  
- 🚀 **Swift 6 Compatibility**

---

## 📋 **Requirements**

- **iOS 13.0+ / macOS 10.15+**
- **Swift 5.5+**
- **Xcode 13.0+**

---

## 📦 **Installation**

### Swift Package Manager (SPM)

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/alessandrostuppino/NetworkManager.git", from: "1.0.0")
]
```

Or use **Xcode**:
1. Go to **File > Add Packages...**
2. Search for:
   ```
   https://github.com/alessandrostuppino/NetworkManager.git
   ```
3. Select the latest version and add it to your project.

---

## 📚 **Usage**

Below are examples of how to use **NetworkManager** for **network requests** as well as **network monitoring** and **VPN detection**.

### 1. Network Requests

#### Initializing APIClient

```swift
let client = APIClient() // Basic initialization with default settings

let client = APIClient(qos: .background) // Initialization with custom QoS (Quality of Service)

let client = APIClient(logLevel: .verbose) // Initialization with custom log level

let client = APIClient(qos: .userInitiated, logLevel: .standard) // With QoS + log level

let client = APIClient(retryHandler: MyCustomRetryHandler()) // With a custom retry handler

let client = APIClient(decoder: MyCustomDecoder()) // With a custom decoder
```

#### Defining an API Endpoint

```swift
struct UserAPI: NetworkRouter {
    typealias Parameters = UserParameters
    typealias QueryParameters = UserQueryParameters

    var baseURLString: String { "https://api.example.com" }
    var method: RequestMethod? { .get }
    var path: String { "/users" }
    var headers: [String: String]? { 
        HeaderHandler.shared
            .addAcceptHeaders(type: .applicationJson)
            .addContentTypeHeader(type: .applicationJson)
            .build() 
    }
    var params: Parameters? { UserParameters(id: 123) }
    var queryParams: QueryParameters? { UserQueryParameters(includeDetails: true) }
}
```

Or using a repository-style approach:

```swift
public protocol SampleRepositoryProtocols: Sendable {
    func getInvoice(documentID: String) async throws -> SomeModel
    func getReceipt(transactionId: String) async throws -> SomeModel
}

public final class SampleRepository: Sendable {
    // MARK: Lifecycle

    public init(client: APIClient) {
        self.client = client
    }

    // MARK: Private

    private let client: APIClient
}

extension SampleRepository {
    enum Router: NetworkRouter {
        case getInvoice(documentID: String)
        case getReceipt(transactionId: String)

        var path: String {
            switch self {
            case .getInvoice(let documentID): "your/path/\(documentID)"
            case .getReceipt(let transactionId): "your/path/\(transactionId)"
            }
        }

        var method: RequestMethod? {
            switch self {
            case .getInvoice: .get
            case .getReceipt: .post
            }
        }

        var headers: [String: String]? {
            var handler = HeaderHandler.shared
                .addAuthorizationHeader()
                .addAcceptHeaders(type: .applicationJson)
                .addDeviceId()
            
            switch self {
            case .getInvoice:
                break
            case .getReceipt:
                handler = handler.addContentTypeHeader(type: .applicationJson)
            }
            
            return handler.build()
        }
        
        var queryParams: SampleRepositoryQueryParamModel? {
            switch self {
            case .getInvoice(let trxId): SampleRepositoryQueryParamModel(trxId: trxId)
            case .getReceipt(let transactionId): SampleRepositoryQueryParamModel(trxId: transactionId)
            }
        }
        
        var params: SampleRepositoryQueryParamModel? {
            switch self {
            case .getInvoice(let documentID):
                SampleRepositoryQueryParamModel(
                    documentId: documentID,
                    stepId: "Some Id",
                    subStepId: "Some Id"
                )
            case .getReceipt: nil
            }
        }
    }
}

extension SampleRepository: SampleRepositoryProtocols {
    public func getInvoice(documentID: String) async throws -> SomeModel {
        try await client.asyncRequest(Router.getInvoice(documentID: documentID))
    }
    
    public func getReceipt(transactionId: String) async throws -> SomeModel {
        try await client.asyncRequest(Router.getReceipt(transactionId: transactionId))
    }
}

public struct SampleRepositoryQueryParamModel: Codable, Sendable {
    public init(documentId: String? = nil, stepId: String? = nil, subStepId: String? = nil, trxId: String? = nil) {
        self.documentId = documentId
        self.stepId = stepId
        self.subStepId = subStepId
        self.trxId = trxId
    }
    
    public let documentId: String?
    public let stepId: String?
    public let subStepId: String?
    public let trxId: String?
}
```

#### Making a Request ⚡

```swift
Task {
    do {
        let userResponse: UserResponse = try await client.asyncRequest(UserAPI())
        print("Received user: \(userResponse)")
    } catch {
        print("Request failed: \(error)")
    }
}
```

#### File Upload 📤

```swift
let apiClient = APIClient()

let fileData = // ... your file data ...
let endpoint = UploadAPI()

Task {
  do {
    let response = try await apiClient.uploadRequest(endpoint, withName: "file", data: fileData) { totalProgress, _, _ in
      debugPrint("total progress \(totalProgress)")
    }
    print("Upload completed: \(response)")
  } catch let error as NetworkError {
    // Handle error
  }
}

```

---

### 2. Network Monitoring

**NetworkManager** provides a simple utility to monitor network status via **NWPathMonitor**, exposing:

- An **async/await** stream
- **VPN detection** integrated by default (but can be bypassed)

Here’s a sample usage:

```swift
import Combine

var cancellables = Set<AnyCancellable>()

// Instantiate the network monitor (optionally disabling VPN detection)
let network = NetworkMonitor(shouldDetectVpnAutomatically: true)

// Start monitoring
network.startMonitoring()

Task {
    let statusStream = network.statusStream()
    for await status in statusStream {
        switch status {
        case .disconnected:
            debugPrint("Async disconnected")
        case .connected(let type):
            debugPrint("Async connected: \(type)")
        }
    }
}
```

---

### 3. VPN Checking

**NetworkManager** includes a standalone `VPNChecker` class that checks whether a VPN is active. It inspects the system’s proxy settings for known VPN interfaces. You can use this independently if you wish:

```swift
let checker = VPNChecker() // Normal usage
let isVPNActive = checker.isVPNActive()
print("VPN Active? \(isVPNActive)")
```

If you want to **bypass** VPN checking (e.g., in debug mode), you can initialize with:

```swift
let checker = VPNChecker(shouldBypassVpnCheck: true)
```

This will always return `false` for `isVPNActive()`.

---

## 🔧 **Customization**

### Retry Handling 🔄

```swift
struct CustomRetryHandler: RetryHandler {
    // MARK: Lifecycle

    init(numberOfRetries: Int) {
        self.numberOfRetries = numberOfRetries
    }

    // MARK: Public

    let numberOfRetries: Int

    func shouldRetry(request: URLRequest, error: NetworkError) -> Bool {
        // Implement your logic here
    }

    func modifyRequestForRetry(client: APIClient, request: URLRequest, error: NetworkError) -> (URLRequest, NetworkError?) {
        // Implement your logic here
    }
}
```

---

## 📱 **Sample SwiftUI App**

A sample SwiftUI app is available to help you get started with **NetworkManager** in a real-world scenario.

**Features of the Sample App**:
- Setup and usage of `APIClient`
- Defining API endpoints using `NetworkRouter`
- Making network requests and handling responses in SwiftUI
- Basic error handling

**Getting the Sample App**:
1. Clone this repository.
2. Navigate to `Example/NetworkManagerExampleApp`.
3. Open `NetworkManagerExampleApp.xcodeproj` in Xcode.
4. Run the project.

---

## 🤝 **Contributing**

We welcome contributions! Feel free to open issues and submit pull requests on [GitHub](https://github.com/alessandrostuppino/NetworkManager).

