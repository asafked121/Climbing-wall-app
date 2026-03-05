import Foundation
import SwiftUI

class CustomRouteListViewModel: ObservableObject {
    @Published var routes: [CustomRoute] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchRoutes() {
        guard let url = URL(string: "\(Config.apiBaseURL)/custom-routes/") else { return }
        
        isLoading = true
        errorMessage = nil
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = KeychainHelper.shared.read(service: "climbapp", account: "token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
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
                
                do {
                    self.routes = try JSONDecoder().decode([CustomRoute].self, from: data)
                } catch {
                    self.errorMessage = "Failed to decode custom routes"
                    print("Decode error:", error)
                }
            }
        }.resume()
    }
}
