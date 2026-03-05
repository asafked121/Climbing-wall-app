import Foundation
import Combine
import SwiftUI

@MainActor
class BulkUploadRoutesViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var isDownloadingTemplate = false
    @Published var uploadResult: BulkUploadResponse?
    @Published var errorMessage: String?
    @Published var templateURL: URL?
    @Published var showDocumentPicker = false
    
    func downloadTemplate() {
        isDownloadingTemplate = true
        errorMessage = nil
        
        Task {
            do {
                let url = try await NetworkManager.shared.downloadBulkTemplate()
                self.templateURL = url
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isDownloadingTemplate = false
        }
    }
    
    func uploadFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            self.errorMessage = "Permission denied to read the selected file."
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        isUploading = true
        errorMessage = nil
        uploadResult = nil
        
        // Create a temporary copy we can safely read
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
        } catch {
            self.errorMessage = "Failed to copy file: \(error.localizedDescription)"
            self.isUploading = false
            return
        }
        
        Task {
            do {
                let result = try await NetworkManager.shared.uploadBulkRoutesFile(fileURL: tempURL)
                self.uploadResult = result
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isUploading = false
            
            // Clean up
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
}
