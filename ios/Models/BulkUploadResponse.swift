import Foundation

struct BulkUploadRowError: Codable, Identifiable {
    var id: UUID { UUID() }
    let row: Int
    let field: String?
    let message: String
}

struct BulkUploadResponse: Codable {
    let totalRows: Int
    let createdCount: Int
    let errorCount: Int
    let errors: [BulkUploadRowError]
    
    enum CodingKeys: String, CodingKey {
        case totalRows = "total_rows"
        case createdCount = "created_count"
        case errorCount = "error_count"
        case errors
    }
}
