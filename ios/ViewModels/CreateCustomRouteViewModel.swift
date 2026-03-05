import Foundation
import UIKit

class CreateCustomRouteViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var photoUrl: String?
    @Published var detectedHolds: [Hold] = []
    @Published var selectedHoldIds: Set<String> = []
    
    struct Hold: Codable, Identifiable {
        let id: String
        let x: Int
        let y: Int
        let radius: Int
    }
    
    func detectHolds(image: UIImage) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(Config.apiBaseURL)/custom-routes/detect-holds"),
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            self.errorMessage = "Failed to prepare image data"
            self.isLoading = false
            return
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = KeychainHelper.shared.read(service: "climbapp", account: "token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                struct DetectResponse: Codable {
                    let photoUrl: String
                    let holds: [Hold]
                    enum CodingKeys: String, CodingKey {
                        case photoUrl = "photo_url"
                        case holds
                    }
                }
                
                do {
                    let res = try JSONDecoder().decode(DetectResponse.self, from: data)
                    self.photoUrl = res.photoUrl
                    self.detectedHolds = res.holds
                } catch {
                    self.errorMessage = "Failed to decode response"
                }
            }
        }.resume()
    }
    
    func createRoute(name: String, intendedGrade: String, completion: @escaping (Bool) -> Void) {
        guard let photoUrl = photoUrl else {
            errorMessage = "Please detect holds first."
            completion(false)
            return
        }
        
        let selectedHolds = detectedHolds.filter { selectedHoldIds.contains($0.id) }
        if selectedHolds.isEmpty {
            errorMessage = "Please select at least one hold."
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(Config.apiBaseURL)/custom-routes/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainHelper.shared.read(service: "climbapp", account: "token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        struct CreateBody: Codable {
            let name: String
            let intendedGrade: String
            let photoUrl: String
            let holds: String
            
            enum CodingKeys: String, CodingKey {
                case name
                case intendedGrade = "intended_grade"
                case photoUrl = "photo_url"
                case holds
            }
        }
        
        do {
            let holdsData = try JSONEncoder().encode(selectedHolds)
            let holdsString = String(data: holdsData, encoding: .utf8) ?? "[]"
            
            let body = CreateBody(name: name, intendedGrade: intendedGrade, photoUrl: photoUrl, holds: holdsString)
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            errorMessage = "Failed to encode request body"
            isLoading = false
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                    completion(true)
                } else {
                    self.errorMessage = "Failed to create route"
                    completion(false)
                }
            }
        }.resume()
    }
}
