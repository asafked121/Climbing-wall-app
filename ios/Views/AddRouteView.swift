import SwiftUI
import PhotosUI

struct AddRouteView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var loginViewModel: LoginViewModel
    @StateObject private var viewModel = AddRouteViewModel()
    
    @State private var selectedItem: PhotosPickerItem?
    
    var onRouteAdded: (() -> Void)?
    
    var canManageRoutes: Bool {
        let role = loginViewModel.currentUser?.role
        return role == "admin" || role == "super_admin" || role == "setter"
    }
    
    var body: some View {
        NavigationView {
            Form {
                if viewModel.isLoading && viewModel.zones.isEmpty {
                    ProgressView("Loading zones...")
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
                                    Text(setter.name).tag(setter.id as Int?)
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
                    }
                    
                    Section(header: Text("Photo (Optional)")) {
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            if let data = viewModel.selectedPhotoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                            } else {
                                Text("Select a photo")
                                    .foregroundColor(.blue)
                            }
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    viewModel.selectedPhotoData = data
                                }
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
            .navigationTitle("Add Route")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        await viewModel.createRoute()
                        if viewModel.isSuccess {
                            onRouteAdded?()
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
