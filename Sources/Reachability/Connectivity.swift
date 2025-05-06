/// Represents the high-level connectivity state:
/// - `.disconnected` for no network.
/// - `.connected(NetworkStatus)` for a network connection of a specific type.
public enum Connectivity: Equatable, Sendable {
  case disconnected
  case connected(NetworkType)
}

/// Represents the underlying network interface type (WiFi, cellular, etc.).
public enum NetworkType: Equatable, Sendable {
  case wifi, cellular, ethernet, other, vpn
}
