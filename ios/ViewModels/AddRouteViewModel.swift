import Foundation
import Combine
import SwiftUI

@MainActor
class AddRouteViewModel: ObservableObject {
    @Published var zones: [Zone] = []
    @Published var setters: [Setter] = []
    @Published var colors: [RouteColor] = []
    @Published var selectedZoneId: Int? {
        didSet { onZoneChanged() }
    }
    @Published var selectedSetterId: Int?
    @Published var selectedColor: RouteColor?
    @Published var selectedGrade: String = "V0"
    @Published var selectedSetDate: Date = Date()
    @Published var selectedPhotoData: Data?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSuccess: Bool = false
    
    /// Returns the correct grade list based on the selected zone's route type.
    var grades: [String] {
        guard let zoneId = selectedZoneId,
              let zone = zones.first(where: { $0.id == zoneId }) else {
            return GradeHelper.boulderGrades
        }
        return GradeHelper.grades(for: zone.routeType)
    }
    
    func fetchData(canManageRoutes: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            zones = try await NetworkManager.shared.fetchZones()
            if let firstZone = zones.first {
                selectedZoneId = firstZone.id
            }
            colors = try await NetworkManager.shared.fetchColors()
            if let firstColor = colors.first {
                selectedColor = firstColor
            }
            if canManageRoutes {
                setters = try await NetworkManager.shared.fetchSetters()
                
                // If the current user matches a setter name, select them
                if let curr = try? await NetworkManager.shared.fetchCurrentUser(), let match = setters.first(where: { $0.name == curr.username }) {
                    selectedSetterId = match.id
                } else if let firstSetter = setters.first {
                    selectedSetterId = firstSetter.id
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func createRoute() async {
        guard let zoneId = selectedZoneId else {
            errorMessage = "Please select a zone"
            return
        }
        
        guard let color = selectedColor else {
            errorMessage = "Please select a hold color"
            return
        }
        
        isLoading = true
        errorMessage = nil
        isSuccess = false
        
        do {
            let route = try await NetworkManager.shared.createRoute(zoneId: zoneId, color: color.hexValue, intendedGrade: selectedGrade, setterId: selectedSetterId, setDate: selectedSetDate)
            
            if let photoData = selectedPhotoData {
                _ = try await NetworkManager.shared.uploadRoutePhoto(routeId: route.id, imageData: photoData)
            }
            
            isSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Reset grade to default when zone changes, since grade systems differ.
    private func onZoneChanged() {
        guard let zoneId = selectedZoneId,
              let zone = zones.first(where: { $0.id == zoneId }) else { return }
        let validGrades = GradeHelper.grades(for: zone.routeType)
        if !validGrades.contains(selectedGrade) {
            selectedGrade = GradeHelper.defaultGrade(for: zone.routeType)
        }
    }
}
