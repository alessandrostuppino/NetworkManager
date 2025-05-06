import Foundation
import NetworkManager

@MainActor
final class UploadViewModel: ObservableObject, Sendable {
  @Published private(set) var uploadResponse: UploadResponse?
  @Published var showError = false
  @Published var errorMessage = ""
  
  private let apiClient = APIClient(logLevel: .verbose)
  
  func upload(file: Data) async throws {
    Task {
      do {
        let response: UploadResponse = try await apiClient.uploadRequest(UploadAPI(), withName: "file", data: file) { totalProgress, _, _ in
          debugPrint("total progress \(totalProgress)")
        }
        self.uploadResponse = response
      } catch let error as NetworkError {
        self.showError = true
        self.errorMessage = error.localizedErrorDescription ?? ""
      }
    }
  }
}
