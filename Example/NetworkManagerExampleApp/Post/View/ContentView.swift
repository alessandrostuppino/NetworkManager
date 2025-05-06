import SwiftUI
import Combine
import NetworkManager

struct ContentView: View {
  @StateObject private var viewModel = PostsViewModel()
  
  var body: some View {
    NavigationView {
      List {
        ForEach(viewModel.posts) { post in
          VStack(alignment: .leading) {
            Text(post.title)
              .font(.headline)
            
            Text(post.body)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("Posts")
      .onAppear {
        Task {
          viewModel.fetchPosts()
        }
      }
      .alert(isPresented: $viewModel.showError) {
        Alert(
          title: Text("Error"),
          message: Text(viewModel.errorMessage),
          dismissButton: .default(Text("OK"))
        )
      }
    }
  }
}

#Preview {
  ContentView()
}
