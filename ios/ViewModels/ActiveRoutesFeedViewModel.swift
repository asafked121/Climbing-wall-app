import Foundation
import Combine

@MainActor
class ActiveRoutesFeedViewModel: ObservableObject {
    @Published var routes: [Route] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var selectedZoneId: Int?
    @Published var selectedGrade: String?
    @Published var selectedStatus: String = "active"
    @Published var selectedRouteType: String = "boulder"
    
    @Published var zones: [Zone] = []
    
    /// Zones filtered to match the currently selected route type.
    var filteredZones: [Zone] {
        zones.filter { $0.routeType == selectedRouteType }
    }
    
    func fetchZones() async {
        do {
            zones = try await NetworkManager.shared.fetchZones()
        } catch {
            print("Failed to fetch zones: \(error.localizedDescription)")
        }
    }
    
    func fetchRoutes() async {
        isLoading = true
        errorMessage = nil
        do {
            routes = try await NetworkManager.shared.fetchRoutes(zoneId: selectedZoneId, grade: selectedGrade, status: selectedStatus, routeType: selectedRouteType)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
