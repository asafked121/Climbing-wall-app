import SwiftUI

struct ZoneListView: View {
    @StateObject private var adminViewModel = AdminViewModel()
    
    @State private var newZoneName = ""
    @State private var newZoneDescription = ""
    @State private var newZoneRouteType = "boulder"
    @State private var newZoneAllowsLead = false
    
    @State private var editingZone: Zone? = nil
    
    private var isAddDisabled: Bool {
        newZoneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        List {
            if editingZone == nil {
                addZoneSection
            } else {
                editZoneSection
            }
            zoneListSection
        }
        .navigationTitle("Wall Zones")
        .refreshable {
            await adminViewModel.fetchZones()
        }
        .onAppear {
            Task {
                await adminViewModel.fetchZones()
            }
        }
        .overlay { loadingOverlay }
        .alert("Error", isPresented: Binding(
            get: { adminViewModel.errorMessage != nil },
            set: { _ in adminViewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = adminViewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Sub-views
    
    private var addZoneSection: some View {
        Section(header: Text("Add New Zone")) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Zone Name (e.g. West Wall)", text: $newZoneName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Description", text: $newZoneDescription)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("Route Type", selection: $newZoneRouteType) {
                    Text("Boulder").tag("boulder")
                    Text("Top Rope").tag("top_rope")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: newZoneRouteType) { newValue in
                    if newValue == "boulder" {
                        newZoneAllowsLead = false
                    }
                }
                
                Toggle("Allows Lead Climbing", isOn: $newZoneAllowsLead)
                    .font(.subheadline)
                    .disabled(newZoneRouteType == "boulder")
                
                Button(action: {
                    Task {
                        await adminViewModel.addZone(
                            name: newZoneName,
                            description: newZoneDescription.isEmpty ? nil : newZoneDescription,
                            routeType: newZoneRouteType,
                            allowsLead: newZoneAllowsLead
                        )
                        newZoneName = ""
                        newZoneDescription = ""
                        newZoneRouteType = "boulder"
                        newZoneAllowsLead = false
                    }
                }) {
                    Text("Add Zone")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAddDisabled)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var editZoneSection: some View {
        Section(header: Text("Edit Zone: \(editingZone?.name ?? "")")) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Zone Name", text: Binding(
                    get: { editingZone?.name ?? "" },
                    set: { editingZone = editingZone.map { Zone(id: $0.id, name: $1, description: $0.description, routeType: $0.routeType, allowsLead: $0.allowsLead) } }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Description", text: Binding(
                    get: { editingZone?.description ?? "" },
                    set: { val in editingZone = editingZone.map { Zone(id: $0.id, name: $0.name, description: val, routeType: $0.routeType, allowsLead: $0.allowsLead) } }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("Route Type", selection: Binding(
                    get: { editingZone?.routeType ?? "boulder" },
                    set: { val in 
                        editingZone = editingZone.map { Zone(id: $0.id, name: $0.name, description: $0.description, routeType: val, allowsLead: val == "boulder" ? false : $0.allowsLead) }
                    }
                )) {
                    Text("Boulder").tag("boulder")
                    Text("Top Rope").tag("top_rope")
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Toggle("Allows Lead Climbing", isOn: Binding(
                    get: { editingZone?.allowsLead ?? false },
                    set: { val in editingZone = editingZone.map { Zone(id: $0.id, name: $0.name, description: $0.description, routeType: $0.routeType, allowsLead: val) } }
                ))
                .font(.subheadline)
                .disabled(editingZone?.routeType == "boulder")
                
                if editingZone?.routeType == "boulder" {
                    Text("Lead only available for Top Rope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Button("Cancel") {
                        editingZone = nil
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        if let zone = editingZone {
                            Task {
                                await adminViewModel.updateZone(
                                    zoneId: zone.id,
                                    name: zone.name,
                                    description: zone.description,
                                    routeType: zone.routeType,
                                    allowsLead: zone.allowsLead
                                )
                                editingZone = nil
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var zoneListSection: some View {
        Section(header: Text("\(adminViewModel.zones.count) Zones")) {
            ForEach(adminViewModel.zones) { zone in
                zoneRow(zone)
            }
        }
    }
    
    private func zoneRow(_ zone: Zone) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(zone.name)
                        .font(.headline)
                    
                    Text(zone.routeType)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    
                    if zone.allowsLead {
                        Text("Lead")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                
                if let desc = zone.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    editingZone = zone
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    Task {
                        await adminViewModel.deleteZone(zoneId: zone.id)
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if adminViewModel.isLoading {
            ZStack {
                Color.black.opacity(0.1)
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 4)
            }
            .ignoresSafeArea()
        }
    }
}

// Extension to allow manual init for Zone in Binding
extension Zone {
    init(id: Int, name: String, description: String?, routeType: String, allowsLead: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.routeType = routeType
        self.allowsLead = allowsLead
    }
}
