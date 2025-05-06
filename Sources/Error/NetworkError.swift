import Foundation

// MARK: - NetworkError

/// An enum representing various network errors.
public enum NetworkError: Error, Sendable {
    case unknown
    case urlError(URLError)
    case decodingError(Error)
    case customError(Int,Data)
    case responseError(Error)
}

// MARK: LocalizedError

extension NetworkError: LocalizedError {
    public var localizedErrorDescription: String? {
        switch self {
        case let .urlError(error): error.localizedDescription
        case let .decodingError(error): error.localizedDescription
        case .customError(_,_): self.localizedDescription
        case let .responseError(error): error.localizedDescription
        case .unknown: self.localizedDescription
        }
    }
}
