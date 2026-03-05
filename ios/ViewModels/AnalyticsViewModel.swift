import Foundation

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var analytics: AnalyticsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Filter state
    @Published var statusFilter: String = "active"     // "", "active", "archived"
    @Published var routeTypeFilter: String = ""         // "", "boulder", "top_rope"
    @Published var dateFrom: Date?
    @Published var dateTo: Date?

    func loadAnalytics() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await NetworkManager.shared.fetchAnalytics(
                status: statusFilter.isEmpty ? nil : statusFilter,
                routeType: routeTypeFilter.isEmpty ? nil : routeTypeFilter,
                dateFrom: dateFrom,
                dateTo: dateTo
            )
            self.analytics = result
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func resetFilters() {
        statusFilter = "active"
        routeTypeFilter = ""
        dateFrom = nil
        dateTo = nil
    }
}
