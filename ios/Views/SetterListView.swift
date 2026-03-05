import SwiftUI

struct SetterListView: View {
    @StateObject private var adminViewModel = AdminViewModel()
    
    @State private var searchText = ""
    @State private var activeFilter: ActiveFilter = .all
    @State private var newSetterName = ""
    
    enum ActiveFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
    }
    
    private var filteredSetters: [Setter] {
        adminViewModel.setters.filter { setter in
            let matchesSearch = searchText.isEmpty
                || setter.name.localizedCaseInsensitiveContains(searchText)
            
            let matchesActive: Bool = {
                switch activeFilter {
                case .all: return true
                case .active: return setter.isActive
                case .inactive: return !setter.isActive
                }
            }()
            
            return matchesSearch && matchesActive
        }
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search setters...", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            
            Section {
                HStack {
                    TextField("New Setter Name", text: $newSetterName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        Task {
                            await adminViewModel.addSetter(name: newSetterName)
                            newSetterName = ""
                        }
                    }
                    .disabled(newSetterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ActiveFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                label: filter.rawValue,
                                isSelected: activeFilter == filter,
                                action: { activeFilter = filter }
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("\(filteredSetters.count) Setters")) {
                ForEach(filteredSetters) { setter in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(setter.name)
                                .font(.body)
                            if !setter.isActive {
                                Text("Inactive")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await adminViewModel.toggleSetterActiveStatus(for: setter)
                            }
                        }) {
                            Text(setter.isActive ? "Deactivate" : "Activate")
                                .font(.caption)
                                .foregroundColor(setter.isActive ? .orange : .green)
                                .padding(6)
                                .background((setter.isActive ? Color.orange : Color.green).opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            Task {
                                await adminViewModel.deleteSetter(setterId: setter.id)
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(6)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Setters")
        .refreshable {
            await adminViewModel.fetchSetters()
        }
        .onAppear {
            Task {
                await adminViewModel.fetchSetters()
            }
        }
        .overlay {
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
}
