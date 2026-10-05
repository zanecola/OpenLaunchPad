import Foundation

/// Tries primary, falls back to secondary on any error.
/// Extensibility point: lets you chain data sources without changing the ViewModel. (ADR-2)
final class CompositeDataSource: AppDataSource {
    private let primary: any AppDataSource
    private let fallback: any AppDataSource

    init(primary: any AppDataSource, fallback: any AppDataSource) {
        self.primary = primary
        self.fallback = fallback
    }

    func loadPages(pageCapacity: Int) throws -> [[LaunchpadItem]] {
        do {
            return try primary.loadPages(pageCapacity: pageCapacity)
        } catch {
            return try fallback.loadPages(pageCapacity: pageCapacity)
        }
    }
}
