import SwiftUI

struct ColorListView: View {
    @StateObject private var adminViewModel = AdminViewModel()
    
    @State private var newColorName = ""
    @State private var newColorHex = "#000000"
    
    private var isAddDisabled: Bool {
        newColorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || newColorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var previewColor: Color {
        Color(hex: newColorHex) ?? Color.clear
    }
    
    var body: some View {
        List {
            addColorSection
            colorListSection
        }
        .navigationTitle("Colors")
        .refreshable {
            await adminViewModel.fetchColors()
        }
        .onAppear {
            Task {
                await adminViewModel.fetchColors()
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
    
    private var addColorSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add New Color")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Color Name (e.g. Neon Green)", text: $newColorName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Text("Hex Value:")
                        .font(.subheadline)
                    
                    TextField("#000000", text: $newColorHex)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .frame(width: 100)
                    
                    Spacer()
                    
                    Circle()
                        .fill(previewColor)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                        .padding(.trailing, 8)
                    
                    Button("Add") {
                        Task {
                            await adminViewModel.addColor(name: newColorName, hexValue: newColorHex)
                            newColorName = ""
                            newColorHex = "#000000"
                        }
                    }
                    .disabled(isAddDisabled)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var colorListSection: some View {
        Section(header: Text("\(adminViewModel.colors.count) Colors")) {
            ForEach(adminViewModel.colors) { color in
                colorRow(color)
            }
        }
    }
    
    private func colorRow(_ color: RouteColor) -> some View {
        let displayColor: Color = Color(hex: color.hexValue) ?? Color.clear
        return HStack {
            Circle()
                .fill(displayColor)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(color.name)
                    .font(.body)
                Text(color.hexValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await adminViewModel.deleteColor(colorId: color.id)
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
