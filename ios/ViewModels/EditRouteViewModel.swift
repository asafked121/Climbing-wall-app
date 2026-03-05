import Foundation
import Combine
import SwiftUI

@MainActor
class EditRouteViewModel: ObservableObject {
    @Published var zones: [Zone] = []
    @Published var setters: [Setter] = []
    @Published var colors: [RouteColor] = []
    
    @Published var selectedZoneId: Int? {
        didSet { onZoneChanged() }
    }
    @Published var selectedSetterId: Int?
    @Published var selectedColor: RouteColor?
    @Published var selectedGrade: String = "V0"
    @Published var selectedStatus: String = "active"
    @Published var selectedSetDate: Date = Date()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSuccess: Bool = false
    
    let statuses = ["active", "archived"]
    
    /// Returns the correct grade list based on the selected zone's route type.
    var grades: [String] {
        guard let zoneId = selectedZoneId,
              let zone = zones.first(where: { $0.id == zoneId }) else {
            return GradeHelper.boulderGrades
        }
        return GradeHelper.grades(for: zone.routeType)
    }
    
    let routeId: Int
    
    init(routeId: Int, currentZoneId: Int?, currentColor: String, currentGrade: String, currentSetterId: Int?, currentStatus: String, currentSetDate: Date) {
        self.routeId = routeId
        // We temporarily store the raw color string inside selectedColorName before we fetch the actual RouteColor objects
        self.initialColorStr = currentColor
        self._selectedZoneId = Published(initialValue: currentZoneId)
        self.selectedGrade = currentGrade
        self.selectedSetterId = currentSetterId
        self.selectedStatus = currentStatus.lowercased()
        self.selectedSetDate = currentSetDate
    }
    
    private let initialColorStr: String
    
    func fetchData(canManageRoutes: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            zones = try await NetworkManager.shared.fetchZones()
            colors = try await NetworkManager.shared.fetchColors()
            
            // Map the initialColor string to a valid RouteColor
            if let matchedColor = colors.first(where: { $0.name.lowercased() == initialColorStr.lowercased() || $0.hexValue.lowercased() == initialColorStr.lowercased() }) {
                selectedColor = matchedColor
            } else if let firstColor = colors.first {
                selectedColor = firstColor
            }
            
            if canManageRoutes {
                setters = try await NetworkManager.shared.fetchSetters()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func updateRoute() async {
        guard let zoneId = selectedZoneId, let color = selectedColor else {
            errorMessage = "Please select a zone and holding color"
            return
        }
        
        isLoading = true
        errorMessage = nil
        isSuccess = false
        
        do {
            _ = try await NetworkManager.shared.updateRoute(
                routeId: routeId,
                zoneId: zoneId,
                color: color.hexValue,
                intendedGrade: selectedGrade,
                setterId: selectedSetterId,
                status: selectedStatus.lowercased(),
                setDate: selectedSetDate
            )
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
