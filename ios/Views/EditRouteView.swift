import SwiftUI

struct EditRouteView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var loginViewModel: LoginViewModel
    @StateObject private var viewModel: EditRouteViewModel
    
    var onRouteEdited: (() -> Void)?
    
    init(routeId: Int, currentZoneId: Int?, currentColor: String, currentGrade: String, currentSetterId: Int?, currentStatus: String, currentSetDate: Date, onRouteEdited: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: EditRouteViewModel(
            routeId: routeId,
            currentZoneId: currentZoneId,
            currentColor: currentColor,
            currentGrade: currentGrade,
            currentSetterId: currentSetterId,
            currentStatus: currentStatus,
            currentSetDate: currentSetDate
        ))
        self.onRouteEdited = onRouteEdited
    }
    
    var canManageRoutes: Bool {
        let role = loginViewModel.currentUser?.role
        return role == "admin" || role == "super_admin" || role == "setter"
    }
    
    var body: some View {
        NavigationView {
            Form {
                if viewModel.isLoading && viewModel.zones.isEmpty {
                    ProgressView("Loading Config...")
                } else if let error = viewModel.errorMessage, viewModel.zones.isEmpty {
                    Section {
                        Text(error).foregroundColor(.red)
                        Button("Retry") {
                            Task { await viewModel.fetchData(canManageRoutes: canManageRoutes) }
                        }
                    }
                } else {
                    Section(header: Text("Route Details")) {
                        Picker("Zone", selection: $viewModel.selectedZoneId) {
                            ForEach(viewModel.zones) { zone in
                                Text(zone.name).tag(zone.id as Int?)
                            }
                        }
                        
                        if canManageRoutes && !viewModel.setters.isEmpty {
                            Picker("Setter", selection: $viewModel.selectedSetterId) {
                                ForEach(viewModel.setters) { setter in
                                    Text("\(setter.name)").tag(setter.id as Int?)
                                }
                            }
                        }
                        
                        Picker("Color", selection: $viewModel.selectedColor) {
                            ForEach(viewModel.colors) { color in
                                Text(color.name).tag(color as RouteColor?)
                            }
                        }
                        
                        Picker("Intended Grade", selection: $viewModel.selectedGrade) {
                            ForEach(viewModel.grades, id: \.self) { grade in
                                Text(grade).tag(grade)
                            }
                        }
                        
                        DatePicker("Set Date", selection: $viewModel.selectedSetDate, displayedComponents: .date)
                        
                        Picker("Status", selection: $viewModel.selectedStatus) {
                            ForEach(viewModel.statuses, id: \.self) { status in
                                Text(status.capitalized).tag(status)
                            }
                        }
                    }
                    
                    if let error = viewModel.errorMessage, !viewModel.zones.isEmpty {
                        Section {
                            Text(error).foregroundColor(.red).font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Edit Route")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        await viewModel.updateRoute()
                        if viewModel.isSuccess {
                            onRouteEdited?()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .disabled(viewModel.isLoading || viewModel.selectedZoneId == nil)
            )
            .task {
                await viewModel.fetchData(canManageRoutes: canManageRoutes)
            }
        }
    }
}
