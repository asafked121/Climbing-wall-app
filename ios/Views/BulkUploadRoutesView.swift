import SwiftUI
import UniformTypeIdentifiers

struct BulkUploadRoutesView: View {
    @StateObject private var viewModel = BulkUploadRoutesViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Instructions Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Upload an Excel file (.xlsx) to bulk create routes. If validation fails, no routes are created.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        instructionRow(title: "zone_name", desc: "Must exist.")
                        instructionRow(title: "setter_name", desc: "Must exist (optional).")
                        instructionRow(title: "color_name", desc: "Must exist.")
                        instructionRow(title: "intended_grade", desc: "Valid for zone type.")
                        instructionRow(title: "set_date", desc: "YYYY-MM-DD (optional).")
                    }
                    .padding(.top, 4)
                    
                    Button(action: {
                        viewModel.downloadTemplate()
                    }) {
                        HStack {
                            if viewModel.isDownloadingTemplate {
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "arrow.down.doc.fill")
                            }
                            Text("Download .xlsx Template")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isDownloadingTemplate)
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Upload Card
                VStack(spacing: 16) {
                    Text("Upload File")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        viewModel.showDocumentPicker = true
                    }) {
                        HStack {
                            if viewModel.isUploading {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Uploading...")
                            } else {
                                Image(systemName: "icloud.and.arrow.up.fill")
                                Text("Select File & Upload")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(viewModel.isUploading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isUploading)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Results Card
                if let result = viewModel.uploadResult {
                    if result.errorCount == 0 {
                        // Success
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Success!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            Text("Successfully processed \(result.totalRows) rows.")
                            Text("Created \(result.createdCount) new routes.")
                            
                            Button("Return to Dashboard") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green, lineWidth: 1))
                        .cornerRadius(12)
                    } else {
                        // Error Table
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Validation Errors (\(result.errorCount))")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            
                            Text("No routes were created. Please fix the following errors:")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Row").bold().frame(width: 50, alignment: .leading)
                                    Text("Column").bold().frame(width: 100, alignment: .leading)
                                    Text("Error").bold().frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.caption)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .background(Color(UIColor.tertiarySystemGroupedBackground))
                                
                                Divider()
                                
                                ForEach(result.errors) { err in
                                    HStack(alignment: .top) {
                                        Text("\(err.row)")
                                            .frame(width: 50, alignment: .leading)
                                        Text(err.field ?? "-")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.red)
                                            .frame(width: 100, alignment: .leading)
                                        Text(err.message)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .font(.caption)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    Divider()
                                }
                            }
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.5), lineWidth: 1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Bulk Import")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $viewModel.showDocumentPicker,
            allowedContentTypes: [UTType.spreadsheet],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.uploadFile(url: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: Binding(
            get: { viewModel.templateURL.map { IdentifiableURL(url: $0) } },
            set: { _ in viewModel.templateURL = nil }
        )) { exportURL in
            ShareSheet(activityItems: [exportURL.url])
        }
    }
    
    private func instructionRow(title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundColor(.secondary)
            Text(title).bold().font(.system(.caption, design: .monospaced))
            Text(": \(desc)").foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

// Helper wrapper for the sheet presentation
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// SwiftUI wrapper for UIActivityViewController to save file
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct BulkUploadRoutesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BulkUploadRoutesView()
        }
    }
}
