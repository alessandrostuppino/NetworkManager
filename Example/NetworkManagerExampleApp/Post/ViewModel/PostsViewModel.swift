import Foundation
import NetworkManager

@MainActor
final class PostsViewModel: ObservableObject, Sendable {
  @Published private(set) var posts: [Post] = []
  @Published var showError = false
  @Published var errorMessage = ""
  
  private let apiClient = APIClient(logLevel: .verbose)
  
  func fetchPosts() {
    Task {
      do {
        let response: [Post] = try await apiClient.request(PostsAPI())
        self.posts = response
      } catch let error as NetworkError {
        self.showError = true
        self.errorMessage = error.localizedErrorDescription ?? ""
      }
    }
  }
}
