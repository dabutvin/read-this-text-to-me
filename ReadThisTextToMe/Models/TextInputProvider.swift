import Foundation

/// Every input source conforms to this protocol.
/// Adding a new source = one new struct + register it.
protocol TextInputProvider: Identifiable, Sendable {
    var id: String { get }
    var displayName: String { get }
    var icon: String { get }       // SF Symbol name
    var priority: Int { get }      // lower = shown first

    /// Extract text from this source. Throws on failure.
    @MainActor
    func extractText() async throws -> String
}
