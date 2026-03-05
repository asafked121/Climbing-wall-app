import SwiftUI

struct ActiveRoutesFeedView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @StateObject private var viewModel = ActiveRoutesFeedViewModel()
    @State private var showingAddRoute = false
    
    var body: some View {
        NavigationView {
            Group {
                VStack {
                    // --- Route Type Toggle (Boulder / Top Rope) ---
                    Picker("Route Type", selection: $viewModel.selectedRouteType) {
                        Text("Boulder").tag("boulder")
                        Text("Top Rope").tag("top_rope")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: viewModel.selectedRouteType) { _ in
                        viewModel.selectedZoneId = nil
                        Task { await viewModel.fetchRoutes() }
                    }
                    
                    if let role = loginViewModel.currentUser?.role.lowercased(), ["admin", "super_admin", "setter"].contains(role) {
                        Picker("Status", selection: $viewModel.selectedStatus) {
                            Text("Active").tag("active")
                            Text("Archived").tag("archived")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: viewModel.selectedStatus) { _ in
                            Task { await viewModel.fetchRoutes() }
                        }
                    }
                    
                    if !viewModel.filteredZones.isEmpty {
                        Picker("Filter by Zone", selection: $viewModel.selectedZoneId) {
                            Text("All Zones").tag(nil as Int?)
                            ForEach(viewModel.filteredZones) { zone in
                                Text(zone.name).tag(zone.id as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        .onChange(of: viewModel.selectedZoneId) { _ in
                            Task { await viewModel.fetchRoutes() }
                        }
                    }
                    
                    if viewModel.isLoading {
                        ProgressView("Loading routes...")
                    } else if let error = viewModel.errorMessage {
                        VStack {
                            Text("Error loading routes:")
                                .foregroundColor(.red)
                            Text(error)
                            Button("Retry") {
                                Task {
                                    await viewModel.fetchRoutes()
                                }
                            }
                            .padding()
                        }
                    } else if viewModel.routes.isEmpty {
                        Text(viewModel.selectedStatus == "active" ? "No active routes found." : "No archived routes found.")
                            .foregroundColor(.secondary)
                    } else {
                        List(viewModel.routes) { route in
                            NavigationLink(destination: RouteDetailView(routeId: route.id)) {
                                HStack {
                                    Circle()
                                        .fill(colorFromName(route.color))
                                        .frame(width: 20, height: 20)
                                    VStack(alignment: .leading) {
                                        Text("\((route.colorName ?? route.color).capitalized) Route")
                                            .font(.headline)
                                        Text("Grade: \(route.intendedGrade)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.selectedStatus == "active" ? "Active Routes" : "Archived Routes")
            .toolbar {
                if let role = loginViewModel.currentUser?.role.lowercased(), ["admin", "super_admin", "setter"].contains(role) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddRoute = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddRoute) {
                AddRouteView {
                    Task {
                        await viewModel.fetchRoutes()
                    }
                }
            }
            .task {
                await viewModel.fetchZones()
                await viewModel.fetchRoutes()
            }
        }
    }
    
    func colorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "black": return .black
        case "white": return .white
        default: return Color(hex: name)
        }
    }
}

struct ActiveRoutesFeedView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveRoutesFeedView()
            .environmentObject(LoginViewModel())
    }
}
